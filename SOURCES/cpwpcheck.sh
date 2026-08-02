#!/bin/bash
#
# Fast, read-only WordPress security audit for cPanel servers.
# No site PHP code is executed and WP-CLI is not required.
#
# by Karl Johnson -- karljohnson.it@gmail.com
# Version 2.0.0
#

VERSION="2.0.0"
HTTPD_CONF="/usr/local/apache/conf/httpd.conf"
EMAIL=""
WORKDIR=""
ERRORS=0
TEMP_FILES=()

RESULT_COUNT=0
RESULT_STATUS=()
RESULT_ACCOUNT=()
RESULT_VERSION=()
RESULT_WP_ROOT=()
RESULT_CONFIG=()
RESULT_MODE=()
RESULT_FINDINGS=()
RESULT_FINDING_COUNT=()

usage() {
	cat <<'EOF'
Usage: cpwpcheck.sh [OPTIONS] [EMAIL]

Fast WordPress security audit for cPanel servers. The default run is read-only,
does not execute site PHP code, and does not require WP-CLI.

Options:
  --email RECIPIENT     Email a copy of the report with mutt
  --httpd-conf FILE     Read DocumentRoot entries from FILE
  --help                Show this help
  --version             Show the script version

Checks:
  - wp-config.php location, ownership, permissions, and symlinks
  - WP_DEBUG enabled on production installations
  - missing or disabled DISALLOW_FILE_EDIT
  - world-writable WordPress core, plugin, and theme files and directories

The audit never changes WordPress files. The report shows critical/warning sites
first and keeps healthy sites compact. One positional EMAIL is accepted for
compatibility with existing cron entries.

Exit status:
  0  Clean audit
  1  Findings remain
  2  Scan, argument, or email-delivery failure
EOF
}

discover_document_roots() {
	awk '
		/^[[:space:]]*#/ { next }
		{
			line = $0
			sub(/^[[:space:]]*DocumentRoot[[:space:]]+/, "", line)
			if (line == $0) next
			if (substr(line, 1, 1) == "\"") {
				line = substr(line, 2)
				end = index(line, "\"")
				if (end) print substr(line, 1, end - 1)
			} else {
				sub(/[[:space:]]+#.*$/, "", line)
				sub(/[[:space:]]+$/, "", line)
				if (line != "") print line
			}
		}
	' "$1" | sort -u
}

locate_wp_config() {
	local root=$1
	local parent

	if [[ -e "$root/wp-config.php" || -L "$root/wp-config.php" ]]; then
		printf '%s\n' "$root/wp-config.php"
		return
	fi

	parent=$(dirname "$root")
	if [[ ( -e "$parent/wp-config.php" || -L "$parent/wp-config.php" ) &&
		! -e "$parent/wp-settings.php" && ! -L "$parent/wp-settings.php" ]]; then
		printf '%s\n' "$parent/wp-config.php"
		return
	fi
	return 1
}

stat_value() {
	stat -c "$1" "$3" 2>/dev/null || stat -f "$2" "$3" 2>/dev/null
}

stat_mode()  { stat_value '%a' '%Lp' "$1"; }
stat_uid()   { stat_value '%u' '%u' "$1"; }
stat_gid()   { stat_value '%g' '%g' "$1"; }
stat_owner() { stat_value '%U' '%Su' "$1"; }

canonical_path() {
	if command -v realpath >/dev/null 2>&1; then
		realpath "$1" 2>/dev/null
	else
		(
			cd -P "$(dirname "$1")" 2>/dev/null || exit 1
			printf '%s/%s\n' "$PWD" "$(basename "$1")"
		)
	fi
}

config_permissions_are_secure() {
	local mode=$1
	local permissions

	[[ "$mode" =~ ^[0-7]{3,4}$ ]] || return 1
	permissions=$((8#$mode))

	(($2 == $4)) || return 1                   # Expected owner.
	((permissions & 0400)) || return 1         # Owner can read.
	((permissions & 0111)) && return 1         # Never executable.
	((permissions & 0027)) && return 1         # No group write or other access.
	((permissions & 0040)) && (($3 != $5)) && return 1
	return 0
}

read_wp_constant() {
	awk -v key="$2" '
		{
			line = $0
			if (block) {
				if (!index(line, "*/")) next
				line = substr(line, index(line, "*/") + 2)
				block = 0
			}
			if (index(line, "/*")) {
				before = substr(line, 1, index(line, "/*") - 1)
				after = substr(line, index(line, "/*") + 2)
				if (index(after, "*/")) {
					line = before substr(after, index(after, "*/") + 2)
				} else {
					line = before
					block = 1
				}
			}
			sub(/[[:space:]]*\/\/.*/, "", line)
			sub(/[[:space:]]*#.*/, "", line)
			gsub(/[[:space:]]/, "", line)
			pos = index(line, "define(")
			if (!pos) next
			value = substr(line, pos + 7)
			quote = substr(value, 1, 1)
			if (quote != "\"" && quote != "\047") next
			value = substr(value, 2)
			end = index(value, quote)
			if (!end || substr(value, 1, end - 1) != key) next
			value = substr(value, end + 2)
			if (tolower(value) ~ /^true[);]/) result = "true"
			else if (tolower(value) ~ /^false[);]/) result = "false"
			else if (substr(value, 1, 1) == "\"" || substr(value, 1, 1) == "\047") {
				quote = substr(value, 1, 1)
				value = substr(value, 2)
				result = substr(value, 1, index(value, quote) - 1)
			} else result = "dynamic"
			print result
			found = 1
			exit
		}
		END { if (!found) print "missing" }
	' "$1"
}

read_wp_version() {
	local version

	version=$(awk -F"'" '/^[[:space:]]*\$wp_version[[:space:]]*=/{print $2; exit}' "$1")
	case "$version" in
		""|*[!0-9A-Za-z.+_-]*) printf '%s\n' "unknown" ;;
		*) printf '%s\n' "$version" ;;
	esac
}

collect_world_writable_code() {
	local root=$1
	local output=$2
	local directory
	local status=0

	: > "$output"
	find -P "$root" -xdev -maxdepth 1 -type f -perm -0002 -print0 \
		>> "$output" 2>/dev/null || status=1
	for directory in "$root" "$root/wp-content"; do
		[[ -d "$directory" ]] || continue
		find -P "$directory" -xdev -maxdepth 0 -type d -perm -0002 -print0 \
			>> "$output" 2>/dev/null || status=1
	done
	for directory in wp-admin wp-includes wp-content/plugins wp-content/themes; do
		[[ -d "$root/$directory" ]] || continue
		find -P "$root/$directory" -xdev \( -type f -o -type d \) \
			-perm -0002 -print0 \
			>> "$output" 2>/dev/null || status=1
	done
	return "$status"
}

display_path() {
	printf '%q' "$1"
}

add_finding() {
	[[ -z "$FINDINGS" ]] || FINDINGS="${FINDINGS}"$'\n'
	FINDINGS="${FINDINGS}$1"
	FINDING_COUNT=$((FINDING_COUNT + 1))
}

record_result() {
	local i=$RESULT_COUNT

	RESULT_STATUS[i]=$1
	RESULT_ACCOUNT[i]=$2
	RESULT_VERSION[i]=$3
	RESULT_WP_ROOT[i]=$4
	RESULT_CONFIG[i]=$5
	RESULT_MODE[i]=$6
	RESULT_FINDINGS[i]=$7
	RESULT_FINDING_COUNT[i]=$8
	RESULT_COUNT=$((RESULT_COUNT + 1))
}

audit_installation() {
	local root=$1
	local document_root=$2
	local config=""
	local mode="-"
	local account uid gid config_uid config_gid environment debug file_edit
	local writable="$WORKDIR/writable.$RESULT_COUNT"
	local path
	local writable_count=0
	local shown=0
	local status="OK"

	FINDINGS=""
	FINDING_COUNT=0
	TEMP_FILES[${#TEMP_FILES[@]}]=$writable
	account=$(stat_owner "$document_root" 2>/dev/null || printf '%s' "unknown")
	uid=$(stat_uid "$document_root" 2>/dev/null || printf '%s' "-1")
	gid=$(stat_gid "$document_root" 2>/dev/null || printf '%s' "-1")

	if config=$(locate_wp_config "$root"); then
		if [[ -L "$config" ]]; then
			add_finding "wp-config.php is a symbolic link and was not followed"
			status="CRITICAL"
		elif [[ -f "$config" ]]; then
			mode=$(stat_mode "$config" 2>/dev/null || printf '%s' "unknown")
			config_uid=$(stat_uid "$config" 2>/dev/null || printf '%s' "-2")
			config_gid=$(stat_gid "$config" 2>/dev/null || printf '%s' "-2")
			if ! config_permissions_are_secure "$mode" "$config_uid" "$config_gid" "$uid" "$gid"; then
				add_finding "wp-config.php ownership or mode $mode is not secure"
			fi

			environment=$(read_wp_constant "$config" WP_ENVIRONMENT_TYPE)
			case "$environment" in local|development|staging) ;; *) environment="production" ;; esac
			debug=$(read_wp_constant "$config" WP_DEBUG)
			[[ "$environment" != "production" || "$debug" != "true" ]] ||
				add_finding "WP_DEBUG is enabled in production"
			file_edit=$(read_wp_constant "$config" DISALLOW_FILE_EDIT)
			[[ "$file_edit" == "true" ]] ||
				add_finding "DISALLOW_FILE_EDIT is not enabled (detected: $file_edit)"
		else
			add_finding "wp-config.php is not a regular file"
		fi
	else
		add_finding "wp-config.php was not found in the WordPress root or valid parent"
	fi

	collect_world_writable_code "$root" "$writable" || {
		add_finding "world-writable code scan did not complete"
		ERRORS=$((ERRORS + 1))
	}
	while IFS= read -r -d '' path; do
		writable_count=$((writable_count + 1))
		if ((shown < 5)); then
			if [[ -d "$path" ]]; then
				add_finding "world-writable code directory: $(display_path "$path")"
			else
				add_finding "world-writable code file: $(display_path "$path")"
			fi
			shown=$((shown + 1))
		fi
	done < "$writable"
	((writable_count <= shown)) ||
		add_finding "$((writable_count - shown)) more world-writable code path(s) omitted"

	if ((writable_count)); then status="CRITICAL"
	elif ((FINDING_COUNT)) && [[ "$status" == "OK" ]]; then status="WARN"
	fi

	record_result "$status" "$account" "$(read_wp_version "$root/wp-includes/version.php")" \
		"$(display_path "$root")" "${config:+$(display_path "$config")}" "$mode" \
		"$FINDINGS" "$FINDING_COUNT"
}

render_report() {
	local i status finding
	local attention=0 healthy=0 critical=0 warnings=0 findings=0
	local rule="=============================================================================="

	for ((i = 0; i < RESULT_COUNT; i++)); do
		status=${RESULT_STATUS[i]}
		findings=$((findings + RESULT_FINDING_COUNT[i]))
		case "$status" in
			CRITICAL) critical=$((critical + 1)); attention=$((attention + 1)) ;;
			WARN) warnings=$((warnings + 1)); attention=$((attention + 1)) ;;
			*) healthy=$((healthy + 1)) ;;
		esac
	done

	printf '%s\n                     WORDPRESS SECURITY CHECK\n%s\n' "$rule" "$rule"
	printf 'Host:       %s\nGenerated:  %s\nMode:       READ-ONLY AUDIT\n' \
		"$(hostname)" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
	printf '\nSUMMARY\n%s\n' "------------------------------------------------------------------------------"
	printf '  Installations %6d    Healthy       %6d\n' "$RESULT_COUNT" "$healthy"
	printf '  Critical      %6d    Warnings      %6d\n' "$critical" "$warnings"
	printf '  Findings      %6d    Errors        %6d\n' "$findings" "$ERRORS"

	printf '\nATTENTION REQUIRED (%d)\n%s\n' "$attention" \
		"------------------------------------------------------------------------------"
	((attention)) || printf '  None.\n'
	for ((i = 0; i < RESULT_COUNT; i++)); do
		status=${RESULT_STATUS[i]}
		[[ "$status" == "CRITICAL" || "$status" == "WARN" ]] || continue
		printf '[%s] #%03d  WordPress %-10s %s\n' \
			"$status" "$((i + 1))" "${RESULT_VERSION[i]}" "${RESULT_WP_ROOT[i]}"
		printf '       Account: %-16s Config mode: %s\n       Config:  %s\n' \
			"${RESULT_ACCOUNT[i]}" "${RESULT_MODE[i]}" "${RESULT_CONFIG[i]:-missing}"
		while IFS= read -r finding; do
			[[ -n "$finding" ]] && printf '       - %s\n' "$finding"
		done <<< "${RESULT_FINDINGS[i]}"
		printf '\n'
	done

	printf '\nHEALTHY INSTALLATIONS (%d)\n%s\n' "$healthy" \
		"------------------------------------------------------------------------------"
	((healthy)) || printf '  None.\n'
	for ((i = 0; i < RESULT_COUNT; i++)); do
		status=${RESULT_STATUS[i]}
		[[ "$status" == "OK" ]] || continue
		printf '[%s] #%03d  %-10s %-16s %s\n' \
			"$status" "$((i + 1))" "${RESULT_VERSION[i]}" \
			"${RESULT_ACCOUNT[i]}" "${RESULT_WP_ROOT[i]}"
	done
	printf '\n%s\nReview every CRITICAL/WARN entry. No WordPress were modified.\n%s\n' \
		"$rule" "$rule"
}

send_report() {
	local report=$1
	local recipient=$2
	local body="${report}.body"
	local status

	TEMP_FILES[${#TEMP_FILES[@]}]=$body
	printf 'Attached is the WordPress security report for %s.\n' "$(hostname)" > "$body"
	mutt -a "$report" -s "WordPress security report for: $(hostname)" \
		-- "$recipient" < "$body"
	status=$?
	return "$status"
}

cleanup() {
	local status=$?
	local file
	local name

	trap - EXIT
	if [[ -d "$WORKDIR" && ! -L "$WORKDIR" &&
		"$WORKDIR" =~ ^/tmp/cpwpcheck\.[[:alnum:]]{6}$ ]]; then
		for file in "${TEMP_FILES[@]}"; do
			[[ "$file" == "$WORKDIR/"* ]] || continue
			name=${file#"$WORKDIR"/}
			[[ -n "$name" && "$name" != "." && "$name" != ".." && "$name" != */* ]] ||
				continue
			rm -f -- "$file"
		done
		rmdir -- "$WORKDIR" 2>/dev/null || true
	fi
	exit "$status"
}

main() {
	local roots report document_root root list version_file wp_root status
	local seen_roots=$'\n'
	local seen_wp=$'\n'

	PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
	LC_ALL=C
	export PATH LC_ALL
	umask 077

	while (($#)); do
		case "$1" in
			--email) shift; (($#)) || { echo "--email requires a recipient" >&2; return 2; }; EMAIL=$1 ;;
			--httpd-conf) shift; (($#)) || { echo "--httpd-conf requires a file" >&2; return 2; }; HTTPD_CONF=$1 ;;
			--help|-h) usage; return ;;
			--version) printf 'cpwpcheck %s\n' "$VERSION"; return ;;
			-*) echo "Unknown option: $1" >&2; usage >&2; return 2 ;;
			*) [[ -z "$EMAIL" ]] || { echo "Only one email recipient is supported" >&2; return 2; }; EMAIL=$1 ;;
		esac
		shift
	done

	case "$EMAIL" in
		*$'\n'*|*$'\r'*)
			echo "Invalid email recipient" >&2
			return 2
			;;
	esac

	[[ -r "$HTTPD_CONF" ]] || { echo "Cannot read: $HTTPD_CONF" >&2; return 2; }

	WORKDIR=$(mktemp -d /tmp/cpwpcheck.XXXXXX) || return 2
	trap cleanup EXIT
	trap 'exit 129' HUP
	trap 'exit 130' INT
	trap 'exit 143' TERM
	roots="$WORKDIR/roots"
	report="$WORKDIR/report"
	TEMP_FILES=("$roots" "$report")
	discover_document_roots "$HTTPD_CONF" > "$roots" || return 2

	while IFS= read -r document_root; do
		[[ -d "$document_root" ]] || continue
		root=$(canonical_path "$document_root") || { ERRORS=$((ERRORS + 1)); continue; }
		[[ "$seen_roots" != *$'\n'"$root"$'\n'* ]] || continue
		seen_roots="${seen_roots}${root}"$'\n'
		list="$WORKDIR/versions.$RESULT_COUNT"
		TEMP_FILES[${#TEMP_FILES[@]}]=$list
		find -P "$root" -xdev -type f -path '*/wp-includes/version.php' -print0 \
			> "$list" 2>/dev/null || ERRORS=$((ERRORS + 1))
		while IFS= read -r -d '' version_file; do
			wp_root=${version_file%/wp-includes/version.php}
			[[ -f "$wp_root/wp-settings.php" && ! -L "$wp_root/wp-settings.php" ]] || continue
			wp_root=$(canonical_path "$wp_root") || continue
			[[ "$seen_wp" != *$'\n'"$wp_root"$'\n'* ]] || continue
			seen_wp="${seen_wp}${wp_root}"$'\n'
			audit_installation "$wp_root" "$root"
		done < "$list"
	done < "$roots"

	render_report > "$report"
	cat "$report"
	if [[ -n "$EMAIL" ]] && ! send_report "$report" "$EMAIL"; then
		echo "Failed to email report to $EMAIL" >&2
		ERRORS=$((ERRORS + 1))
	fi

	((ERRORS == 0)) || return 2
	for ((status = 0; status < RESULT_COUNT; status++)); do
		((RESULT_FINDING_COUNT[status] == 0)) || return 1
	done
	return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
