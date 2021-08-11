#!/usr/bin/env bash
# shellcheck source=/dev/null

###################################################
# Default curl command used for gdrive api requests.
###################################################
_api_request() {
    # shellcheck disable=SC2086
    _curl --compressed ${CURL_PROGRESS} \
        -e "https://drive.google.com" \
        "${API_URL}/drive/${API_VERSION}/${1:?}&key=${API_KEY}&supportsAllDrives=true&includeItemsFromAllDrives=true" || return 1
    _clear_line 1 1>&2
}

###################################################
# A simple wrapper to check tempfile for access token and make authorized oauth requests to drive api
###################################################
_api_request_oauth() {
    . "${TMPFILE}_ACCESS_TOKEN"

    # shellcheck disable=SC2086
    _curl --compressed ${CURL_PROGRESS} \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        "${API_URL}/drive/${API_VERSION}/${1:?}&supportsAllDrives=true&includeItemsFromAllDrives=true" || return 1
    _clear_line 1 1>&2
}

###################################################
# Check if the file ID exists and determine it's type [ folder | Files ].
# Todo: write doc
###################################################
_check_id() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    "${EXTRA_LOG}" "justify" "Validating URL/ID.." "-"
    declare id="${1}" json && unset NAME SIZE
    if json="$("${API_REQUEST_FUNCTION}" "files/${id}?alt=json&fields=name,size,mimeType")"; then
        if ! _json_value code 1 1 <<< "${json}" 2>| /dev/null 1>&2; then
            NAME="$(_json_value name 1 1 <<< "${json}" || :)"
            mime="$(_json_value mimeType 1 1 <<< "${json}" || :)"
            _clear_line 1
            if [[ ${mime} =~ folder ]]; then
                FOLDER_ID="${id}"
                _print_center "justify" "Folder Detected" "=" && _newline "\n"
            else
                SIZE="$(_json_value size 1 1 <<< "${json}" || :)"
                FILE_ID="${id}"
                _print_center "justify" "File Detected" "=" && _newline "\n"
            fi
            export NAME SIZE FILE_ID FOLDER_ID
        else
            _clear_line 1 && "${QUIET:-_print_center}" "justify" "Invalid URL/ID" "=" && _newline "\n"
            return 1
        fi
    else
        _clear_line 1
        "${QUIET:-_print_center}" "justify" "Error: Cannot check URL/ID" "="
        printf "%s\n" "${json}"
        return 1
    fi
    return 0
}

###################################################
# Extract ID from a googledrive folder/file url.
# Arguments: 1
#   ${1} = googledrive folder/file url.
# Result: print extracted ID
###################################################
_extract_id() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare LC_ALL=C ID="${1}"
    case "${ID}" in
        *'drive.google.com'*'id='*) ID="${ID##*id=}" && ID="${ID%%\?*}" && ID="${ID%%\&*}" ;;
        *'drive.google.com'*'file/d/'* | 'http'*'docs.google.com'*'/d/'*) ID="${ID##*\/d\/}" && ID="${ID%%\/*}" && ID="${ID%%\?*}" && ID="${ID%%\&*}" ;;
        *'drive.google.com'*'drive'*'folders'*) ID="${ID##*\/folders\/}" && ID="${ID%%\?*}" && ID="${ID%%\&*}" ;;
    esac
    printf "%b" "${ID:+${ID}\n}"
}

export -f _api_request \
    _api_request_oauth \
    _check_id \
    _extract_id
