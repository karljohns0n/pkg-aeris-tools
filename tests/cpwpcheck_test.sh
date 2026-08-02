#!/bin/bash
# Variables assigned by this harness are consumed by functions in the sourced script.
# shellcheck disable=SC2034

set -uo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$REPO_ROOT/SOURCES/cpwpcheck.sh"
TEST_TMP=""
FAILURES=0
CURRENT_TEST_FAILED=0

fail()
{
	echo "    FAIL: $*" >&2
	CURRENT_TEST_FAILED=1
	return 1
}

assert_contains()
{
	local haystack=$1
	local needle=$2

	[[ "$haystack" == *"$needle"* ]] || fail "Expected output to contain: $needle"
}

assert_not_contains()
{
	local haystack=$1
	local needle=$2

	[[ "$haystack" != *"$needle"* ]] || fail "Expected output not to contain: $needle"
}

assert_equals()
{
	local expected=$1
	local actual=$2

	[[ "$actual" == "$expected" ]] || fail "Expected '$expected', got '$actual'"
}

assert_before()
{
	local haystack=$1
	local first=$2
	local second=$3
	local without_first

	without_first=${haystack#*"$first"}
	[[ "$without_first" != "$haystack" ]] || fail "Missing first marker: $first"
	[[ "$without_first" == *"$second"* ]] || fail "Expected '$first' before '$second'"
}

make_wp_install()
{
	local root=$1
	local version=${2:-6.8.2}

	mkdir -p "$root/wp-admin" "$root/wp-includes" "$root/wp-content/plugins" \
		"$root/wp-content/themes" "$root/wp-content/uploads"
	printf '%s\n' "<?php" "\$wp_version = '$version';" > "$root/wp-includes/version.php"
	printf '%s\n' "<?php" > "$root/wp-settings.php"
}

snapshot_tree()
{
	local root=$1
	local path
	local type

	while IFS= read -r path; do
		if [[ -L "$path" ]]; then
			type="link"
		elif [[ -d "$path" ]]; then
			type="directory"
		else
			type="file"
		fi

		printf '%s|%s|%s|' "$path" "$type" "$(stat_mode "$path")"
		if [[ "$type" == "file" ]]; then
			cksum < "$path"
		else
			printf '%s\n' "-"
		fi
	done < <(find -P "$root" -print | LC_ALL=C sort)
}

test_script_has_safe_source_guard()
{
	# shellcheck disable=SC2016
	grep -Fq 'if [[ "${BASH_SOURCE[0]}" == "$0" ]]' "$SCRIPT" ||
		fail "Script must not execute main when sourced"
}

test_help_contains_operator_guidance()
{
	local output

	output=$("$SCRIPT" --help)
	assert_contains "$output" "Checks:"
	assert_contains "$output" "WP_DEBUG"
	assert_contains "$output" "DISALLOW_FILE_EDIT"
	assert_contains "$output" "world-writable"
	assert_contains "$output" "Exit status:"
	assert_not_contains "$output" "--show-all"
}

test_script_has_no_wordpress_mutation_path()
{
	local source

	source=$(< "$SCRIPT")
	assert_not_contains "$source" "--fix-permissions"
	assert_not_contains "$source" "runuser"
	assert_not_contains "$source" "chmod 600"
}

test_script_has_no_recursive_delete()
{
	local source

	source=$(< "$SCRIPT")
	assert_not_contains "$source" "rm -rf"
}

test_cleanup_only_removes_registered_temp_files()
{
	local cleanup_root
	local registered
	local unexpected

	cleanup_root=$(mktemp -d /tmp/cpwpcheck.XXXXXX)
	registered="$cleanup_root/report"
	unexpected="$cleanup_root/unexpected"

	printf '%s\n' "report" > "$registered"
	printf '%s\n' "keep" > "$unexpected"

	(
		WORKDIR="$cleanup_root"
		TEMP_FILES=("$registered")
		cleanup
	)

	[[ ! -e "$registered" ]] || fail "Registered temporary file was not removed"
	[[ -f "$unexpected" ]] || fail "Cleanup removed an unregistered file"
	[[ -d "$cleanup_root" ]] || fail "Cleanup removed a non-empty directory"

	rm -f -- "$registered" "$unexpected"
	rmdir -- "$cleanup_root" 2>/dev/null || true
}

test_removed_permission_repair_option_is_rejected()
{
	local output
	local status

	set +e
	output=$("$SCRIPT" --fix-permissions 2>&1)
	status=$?

	assert_equals "2" "$status"
	assert_contains "$output" "Unknown option: --fix-permissions"
}

test_removed_show_all_option_is_rejected()
{
	local output
	local status

	set +e
	output=$("$SCRIPT" --show-all 2>&1)
	status=$?

	assert_equals "2" "$status"
	assert_contains "$output" "Unknown option: --show-all"
}

test_email_recipient_rejects_newlines()
{
	local config="$TEST_TMP/email-httpd.conf"
	local output
	local status

	printf '%s\n' "# no document roots" > "$config"
	set +e
	output=$("$SCRIPT" --httpd-conf "$config" --email $'ops@example.com\nBcc: attacker@example.com' 2>&1)
	status=$?

	assert_equals "2" "$status"
	assert_contains "$output" "Invalid email recipient"
}

test_document_root_parser_handles_realistic_apache_syntax()
{
	local config="$TEST_TMP/httpd.conf"
	local actual

	cat > "$config" <<'EOF'
# DocumentRoot "/ignored/commented"
DocumentRoot /home/alice/public_html
    DocumentRoot "/home/bob/site root"
DocumentRoot "/home/alice/public_html"
EOF

	actual=$(discover_document_roots "$config")
	assert_equals $'/home/alice/public_html\n/home/bob/site root' "$actual"
}

test_config_lookup_follows_wordpress_order_without_recursive_search()
{
	local home="$TEST_TMP/home/alice"
	local root="$home/public_html/site"
	local actual

	make_wp_install "$root"
	printf '%s\n' "<?php" > "$root/wp-config.php"
	mkdir -p "$home/public_html/unrelated"
	printf '%s\n' "<?php" > "$home/public_html/unrelated/wp-config.php"

	actual=$(locate_wp_config "$root")
	assert_equals "$root/wp-config.php" "$actual"

	rm "$root/wp-config.php"
	printf '%s\n' "<?php" > "$home/public_html/wp-config.php"
	actual=$(locate_wp_config "$root")
	assert_equals "$home/public_html/wp-config.php" "$actual"

	printf '%s\n' "<?php" > "$home/public_html/wp-settings.php"
	if locate_wp_config "$root" >/dev/null; then
		fail "A parent WordPress root must not provide a nested install's config"
	fi
}

test_permission_policy_accepts_hardened_modes_only()
{
	local mode

	for mode in 400 440 600 640; do
		config_permissions_are_secure "$mode" 1001 1001 1001 1001 ||
			fail "Expected mode $mode to be accepted"
	done

	for mode in 000 444 644 660 666 755; do
		if config_permissions_are_secure "$mode" 1001 1001 1001 1001; then
			fail "Expected mode $mode to be rejected"
		fi
	done

	if config_permissions_are_secure 600 1002 1001 1001 1001; then
		fail "Config owned by another account must be rejected"
	fi

	if config_permissions_are_secure 440 1001 1002 1001 1001; then
		fail "Group-readable config must use the account's primary group"
	fi
}

test_wordpress_constants_are_read_without_executing_php()
{
	local config="$TEST_TMP/wp-config.php"

	cat > "$config" <<'EOF'
<?php
// define('WP_DEBUG', true);
define( 'WP_DEBUG', false );
define('DISALLOW_FILE_EDIT', true);
define('WP_ENVIRONMENT_TYPE', 'staging');
EOF

	assert_equals "false" "$(read_wp_constant "$config" WP_DEBUG)"
	assert_equals "true" "$(read_wp_constant "$config" DISALLOW_FILE_EDIT)"
	assert_equals "staging" "$(read_wp_constant "$config" WP_ENVIRONMENT_TYPE)"
	assert_equals "missing" "$(read_wp_constant "$config" UNKNOWN_CONSTANT)"
}

test_world_writable_scan_includes_code_files_and_directories_only()
{
	local root="$TEST_TMP/world-writable"
	local results="$TEST_TMP/world-writable-results"
	local -a paths=()
	local path

	make_wp_install "$root"
	mkdir -p "$root/wp-content/plugins/writable-plugin-dir" \
		"$root/wp-content/themes/writable-theme-dir"
	touch "$root/wp-login.php" "$root/wp-admin/admin.php" \
		"$root/wp-content/plugins/plugin.php" "$root/wp-content/themes/theme.php" \
		"$root/wp-content/uploads/upload.php"
	chmod 666 "$root/wp-login.php" "$root/wp-admin/admin.php" \
		"$root/wp-content/plugins/plugin.php" "$root/wp-content/themes/theme.php" \
		"$root/wp-content/uploads/upload.php"
	chmod 777 "$root" "$root/wp-content" "$root/wp-admin" \
		"$root/wp-content/plugins/writable-plugin-dir" \
		"$root/wp-content/themes/writable-theme-dir" \
		"$root/wp-content/uploads"

	collect_world_writable_code "$root" "$results"
	while IFS= read -r -d '' path; do
		paths[${#paths[@]}]=$path
	done < "$results"

	assert_equals "9" "${#paths[@]}"
	assert_contains "$(printf '%s\n' "${paths[@]}")" "$root"
	assert_contains "$(printf '%s\n' "${paths[@]}")" "$root/wp-content"
	assert_contains "$(printf '%s\n' "${paths[@]}")" "$root/wp-admin"
	assert_contains "$(printf '%s\n' "${paths[@]}")" \
		"wp-content/plugins/writable-plugin-dir"
	assert_contains "$(printf '%s\n' "${paths[@]}")" \
		"wp-content/themes/writable-theme-dir"
	assert_not_contains "$(printf '%s\n' "${paths[@]}")" "wp-content/uploads/upload.php"
	assert_not_contains "$(printf '%s\n' "${paths[@]}")" "$root/wp-content/uploads"
}

test_read_only_audit_preserves_wordpress_tree()
{
	local root="$TEST_TMP/read-only-site"
	local config="$TEST_TMP/read-only-httpd.conf"
	local before
	local after
	local output
	local status

	make_wp_install "$root"
	cat > "$root/wp-config.php" <<'EOF'
<?php
define('WP_DEBUG', false);
define('DISALLOW_FILE_EDIT', true);
EOF
	chmod 644 "$root/wp-config.php"
	printf 'DocumentRoot "%s"\n' "$root" > "$config"
	before=$(snapshot_tree "$root")

	set +e
	output=$("$SCRIPT" --httpd-conf "$config" 2>&1)
	status=$?
	after=$(snapshot_tree "$root")

	assert_equals "1" "$status"
	assert_contains "$output" "Mode:       READ-ONLY AUDIT"
	assert_equals "$before" "$after"
}

test_large_report_puts_attention_first_and_shows_all_healthy_rows()
{
	local fixture="$TEST_TMP/fleet"
	local bad="$fixture/bad site"
	local healthy="$fixture/healthy"
	local config="$fixture/httpd.conf"
	local output
	local status

	make_wp_install "$bad" "6.7.2"
	make_wp_install "$healthy" "6.8.2"
	cat > "$bad/wp-config.php" <<'EOF'
<?php
define('WP_DEBUG', true);
EOF
	cat > "$healthy/wp-config.php" <<'EOF'
<?php
define('WP_ENVIRONMENT_TYPE', 'staging');
define('WP_DEBUG', true);
define('DISALLOW_FILE_EDIT', true);
EOF
	chmod 644 "$bad/wp-config.php"
	chmod 600 "$healthy/wp-config.php"
	touch "$bad/wp-content/plugins/unsafe.php"
	chmod 666 "$bad/wp-content/plugins/unsafe.php"

	cat > "$config" <<EOF
DocumentRoot "$bad"
DocumentRoot "$healthy"
EOF

	set +e
	output=$("$SCRIPT" --httpd-conf "$config" 2>&1)
	status=$?

	assert_equals "1" "$status"
	assert_contains "$output" "WORDPRESS SECURITY CHECK"
	assert_contains "$output" "SUMMARY"
	assert_contains "$output" "Installations"
	assert_contains "$output" "ATTENTION REQUIRED (1)"
	assert_contains "$output" "HEALTHY INSTALLATIONS (1)"
	assert_before "$output" "ATTENTION REQUIRED (1)" "HEALTHY INSTALLATIONS (1)"
	assert_contains "$output" "WP_DEBUG is enabled in production"
	assert_contains "$output" "DISALLOW_FILE_EDIT is not enabled"
	assert_contains "$output" "world-writable code file"
	assert_contains "$output" "[OK]"

	RESULT_COUNT=0
	RESULT_STATUS=()
	RESULT_ACCOUNT=()
	RESULT_VERSION=()
	RESULT_WP_ROOT=()
	RESULT_CONFIG=()
	RESULT_MODE=()
	RESULT_FINDINGS=()
	RESULT_FINDING_COUNT=()
	for index in $(seq 1 25); do
		record_result OK "user$index" 6.8.2 "/home/user$index/public_html" \
			"/home/user$index/wp-config.php" 600 "" 0
	done

	output=$(render_report)
	assert_not_contains "$output" "installation(s) omitted"
	assert_contains "$output" "/home/user25/public_html"
}

test_mail_failure_is_returned_to_the_caller()
{
	local report="$TEST_TMP/report.txt"

	printf '%s\n' "report" > "$report"
	# shellcheck disable=SC2329
	mutt()
	{
		return 75
	}

	if send_report "$report" "ops@example.com"; then
		fail "Mailer failure must be returned"
	fi
}

run_test()
{
	local name=$1

	printf '  %-72s' "$name"
	CURRENT_TEST_FAILED=0
	"$name"
	if ((CURRENT_TEST_FAILED == 0)); then
		echo "PASS"
	else
		echo "FAIL"
		FAILURES=$((FAILURES + 1))
	fi
}

main()
{
	TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/cpwpcheck-test.XXXXXX")
	trap 'rm -rf -- "$TEST_TMP"' EXIT

	run_test test_script_has_safe_source_guard
	run_test test_help_contains_operator_guidance
	run_test test_script_has_no_wordpress_mutation_path
	run_test test_script_has_no_recursive_delete
	run_test test_removed_permission_repair_option_is_rejected
	run_test test_removed_show_all_option_is_rejected
	run_test test_email_recipient_rejects_newlines

	# shellcheck disable=SC2016
	if ! grep -Fq 'if [[ "${BASH_SOURCE[0]}" == "$0" ]]' "$SCRIPT"; then
		echo
		echo "Source guard is missing; remaining behavior tests require the refactored script."
		exit 1
	fi

	# shellcheck disable=SC1090
	source "$SCRIPT"

	run_test test_cleanup_only_removes_registered_temp_files
	run_test test_document_root_parser_handles_realistic_apache_syntax
	run_test test_config_lookup_follows_wordpress_order_without_recursive_search
	run_test test_permission_policy_accepts_hardened_modes_only
	run_test test_wordpress_constants_are_read_without_executing_php
	run_test test_world_writable_scan_includes_code_files_and_directories_only
	run_test test_read_only_audit_preserves_wordpress_tree
	run_test test_large_report_puts_attention_first_and_shows_all_healthy_rows
	run_test test_mail_failure_is_returned_to_the_caller

	echo
	if ((FAILURES > 0)); then
		echo "$FAILURES test(s) failed."
		exit 1
	fi

	echo "All cpwpcheck tests passed."
}

main "$@"
