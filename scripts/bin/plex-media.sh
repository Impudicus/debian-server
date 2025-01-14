#!/bin/bash

set -o pipefail # Exit when a command in a pipeline fails

readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_TIME=$SECONDS

getPackageInstallState() {
    local package_name="$1"
    dpkg --list | awk '{print $2}' | grep --line-regexp "$package_name" > /dev/null
    return $?
}

plexGetRunstate() {
    local plex_url="http://127.0.0.1:32400/web/index.html"
    curl --silent --head --fail "$plex_url" | grep --quiet "200 OK"
    return $?
}

validateCollections() {
    plexFetchLibrary() {
        local plex_url="http://127.0.0.1:32400/library/sections/1/all?X-Plex-Token=$PLEX_API_KEY&includeGuids=1"
        curl --silent --header "Accept: application/json" "$plex_url"
        return $?
    }
    plexFetchMovie() {
        local movie_id="$1"
        local movie_libary="$2" || plexFetchLibrary
        local movie_key=$(echo "$movie_libary" | jq --raw-output --arg movie_id "tmdb://$movie_id" '.MediaContainer.Metadata[] | select(.Guid[1].id == $movie_id) | .ratingKey')
        if [[ -z "$movie_key" || "$movie_key" == "null" ]]; then
            return 1
        fi
        return 0
    }

    tmdbFetchCollection() {
        local collection_id="$1"
        local tmdb_url="https://api.themoviedb.org/3/collection/$collection_id?api_key=$TMDB_API_KEY&language=de-DE"
        curl --silent --header "Accept: application/json" "$tmdb_url"
        return $?
    }
    tmdbFetchMovie() {
        local tmdb_id="$1"
        local tmdb_url="https://api.themoviedb.org/3/movie/$tmdb_id?api_key=$TMDB_API_KEY&language=de-DE"
        curl --silent --header "Accept: application/json" "$tmdb_url"
        return $?
    }

    # --------------------------------------------------
    declare -A processed_collections
    declare -A processed_movies

    local movie_libary=$(plexFetchLibrary)
    echo "$movie_libary" | jq --compact-output '.MediaContainer.Metadata[]' | while read -r movie; do
        local movie_title=$(echo "$movie" | jq --raw-output '.title')
        local movie_id=$(echo "$movie" | jq --raw-output '.Guid[1].id' | grep --only-matching --perl-regexp '[0-9]+')
        if [[ -z "$movie_id" || "$movie_id" == "null" ]]; then
            continue
        fi

        local collection_id=$(tmdbFetchMovie "$movie_id" | jq --raw-output '.belongs_to_collection.id')
        if [[ -z "$collection_id" || "$collection_id" == "null" ]]; then
            continue
        elif [[ -n "${processed_collections[$collection_id]}" ]]; then
            continue
        else
            processed_collections[$collection_id]=1
        fi

        tmdbFetchCollection "$collection_id" | jq --compact-output '.parts[]' | while read -r part; do
            local part_title=$(echo "$part" | jq --raw-output '.title')
            local part_id=$(echo "$part" | jq --raw-output '.id')
            local part_release=$(echo "$part" | jq --raw-output '.release_date')
            if [[ -z "$part_id" || "$part_id" == "null" ]]; then
                continue
            elif [[ -n "${processed_movies[$part_id]}" ]]; then
                continue
            else
                processed_movies[$part_id]=1
            fi

            # skip not yet released movies
            if [[ -z "$part_release" || "$part_release" == "null" ]]; then
                continue
            elif [[ $(date '+%s') -lt $(date --date "$part_release" '+%s') ]]; then
                continue
            fi

            plexFetchMovie "$part_id" "$movie_libary" || {
                local part_release_year=$(date --date "$part_release" '+%Y')
                printLog "text" "$part_title ($part_release_year)"
            }
        done &
    done
    wait
    return 0
}

validateEpisodes() {
    plexFetchLibrary() {
        local plex_url="http://127.0.0.1:32400/library/sections/2/all?X-Plex-Token=$PLEX_API_KEY&includeGuids=1"
        curl --silent --header "Accept: application/json" "$plex_url"
        return $?
    }
    plexFetchEpisodes() {
        local plex_key="$1"
        local plex_url="http://127.0.0.1:32400/library/metadata/$plex_key/children?X-Plex-Token=$PLEX_API_KEY&includeGuids=1"
        local tv_show=$(curl --silent --header "Accept: application/json" "$plex_url")
        local tv_episodes=$(echo "$tv_show" | jq --raw-output ".MediaContainer.Metadata[] | select(.index == $season) | .leafCount")
        if [[ -z "$tv_episodes" || "$tv_episodes" == "null" ]]; then
            return 1
        fi
        echo "$tv_episodes"
        return $?
    }

    tmdbFetchShow() {
        local tmdb_id="$1"
        local tmdb_url="https://api.themoviedb.org/3/tv/$tmdb_id?api_key=$TMDB_API_KEY&language=de-DE"
        curl --silent --header "Accept: application/json" "$tmdb_url"
        return $?
    }
    tmdbFetchSeason() {
        local tmdb_id="$1"
        local season_id="$2"
        local tmdb_url="https://api.themoviedb.org/3/tv/$tmdb_id/season/$season_id?api_key=$TMDB_API_KEY&language=de-DE"
        curl --silent --header "Accept: application/json" "$tmdb_url"
        return $?
    }

    # --------------------------------------------------
    local series_libary=$(plexFetchLibrary)
    echo "$series_libary" | jq --compact-output '.MediaContainer.Metadata[]' | while read -r show; do
        local show_title=$(echo "$show" | jq --raw-output '.title')
        local show_key=$(echo "$show" | jq --raw-output '.ratingKey')
        local show_year=$(echo "$show" | jq --raw-output '.year')
        local show_id=$(echo "$show" | jq --raw-output '.Guid[1].id' | grep --only-matching --perl-regexp '[0-9]+')
        if [[ -z "$show_id" || "$show_id" == "null" ]]; then
            continue
        fi

        local season_count=$(tmdbFetchShow "$show_id" | jq --raw-output '.number_of_seasons')
        for season in $(seq 1 "$season_count"); do
            tmdbFetchSeason "$show_id" "$season" | jq --compact-output '.' | while read -r part; do
                # skip not yet released seasons
                local tmdb_release=$(echo "$part" | jq --raw-output '.air_date')
                if [[ -z "$tmdb_release" || "$tmdb_release" == "null" ]]; then
                    continue
                elif [[ $(date '+%s') -lt $(date --date "$tmdb_release" '+%s') ]]; then
                    continue
                fi

                local tmdb_episode_count=$(echo "$part" | jq --raw-output '.episodes | length')
                local plex_episode_count=$(plexFetchEpisodes "$show_key" "$season")
                if [[ "$plex_episode_count" -eq 0 ]]; then
                    printLog "text" "$show_title ($show_year) » season $(printf %02d $season) (full)"
                elif [[ "$plex_episode_count" -lt "$tmdb_episode_count" ]]; then
                    local missing_episodes=$((tmdb_episode_count - plex_episode_count))
                    printLog "text" "$show_title ($show_year) » season $(printf %02d $season) ($missing_episodes/$tmdb_episode_count)"
                fi
            done
        done &
    done
    wait
    return 0
}

validateDuplicates() {
    local work_dir="/mnt/pool2/$1"
    find "$work_dir" -mindepth 1 -type d | while read -r dir; do
        find "$dir" -type f -name "*.mkv" | while read -r file; do
            local file_name=$(basename "$file")

            declare -A processed_elements

            # MOVIES
            local movie_pattern='^.*\s\([0-9]{4}\)\s.*\.mkv$'
            if [[ "$file_name" =~ $movie_pattern ]]; then
                local prefix=$(echo "$file_name" | grep --only-matching --perl-regexp '^.*\s\([0-9]{4}\)')
                if [[ -n "${processed_elements[$prefix]}" ]]; then
                    printLog "text" "$file_name"
                else
                    processed_elements[$prefix]=1
                fi
                continue
            fi

            # SERIES
            local series_pattern='^.*\sS[0-9]{2}E[0-9]{2}.*\.mkv$'
            if [[ "$file_name" =~ $series_pattern ]]; then
                local prefix=$(echo "$file_name" | grep --only-matching --perl-regexp '^.*\sS[0-9]{2}E[0-9]{2}')
                if [[ -n "${processed_elements[$prefix]}" ]]; then
                    printLog "text" "$file_name"
                else
                    processed_elements[$prefix]=1
                fi
                continue
            fi

            # UNKNOWN
            printLog "warn" "$file_name"
        done &
    done
    wait
    return 0
}

printHelp() {
    echo "Usage: $SCRIPT_NAME [options] library"
    echo "Options:"
    echo "  -d, --duplicates                    Validate duplicate media files."
    echo "  -h, --help                          Show this help message."
    echo "  -m, --missing                       Validate missing media files."
    echo "Libraries:"
    echo "  movies                              Run tasks on movies."
    echo "  series                              Run tasks on series."
}
printLog() {
    local error_type="$1"
    local log_message="$2"

    case "$error_type" in
        error)
            echo -e "\e[91m[ERROR]\e[39m $log_message"
            ;;
        warn)
            echo -e "\e[93m[WARN]\e[39m $log_message"
            ;;
        info)
            echo -e "\e[96m[INFO]\e[39m $log_message"
            ;;
        success)
            echo -e "\e[92m[SUCCESS]\e[39m $log_message"
            ;;
        *)
            echo -e "$log_message"
            ;;
    esac
}

main() {
    # --------------------------------------------------
    # Prechecks
    getPackageInstallState "curl" || {
        printLog "error" "Package 'curl' not installed!"
        exit 1
    }

    plexGetRunstate || {
        printLog "error" "Plex Media Server not running!"
        exit 1
    }

    # --------------------------------------------------
    # Variables
    local has_option=''
    local validate_duplicates=''
    local validate_missing=''
    local library=''

    # --------------------------------------------------
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        local parameter="$1"
        case "$parameter" in
            movies)
                library='movies'
                break
                ;;
            series)
                library='series'
                break
                ;;
            -d|--duplicates)
                validate_duplicates='true'
                has_option='true'
                ;;
            -m|--missing)
                validate_missing='true'
                has_option='true'
                ;;
            -h|--help)
                printHelp
                exit 0
                ;;
            *)
                printLog "error" "Unknown parameter '$parameter'; use --help for further information!"
                exit 1
                ;;
        esac
        shift
    done

    if [[ -z "$library" ]]; then
        printLog "error" "Missing library; use --help for further information!"
        exit 1
    elif [[ -z "$has_option" ]]; then
        printLog "error" "Missing options; use --help for further information!"
        exit 1
    fi

    # --------------------------------------------------
    source '/etc/environment' || {
        printLog "error" "Unable to load configuration file!"
        exit 1
    }

    printLog "info" "Library set to '$library'."
    if [[ -n "$validate_duplicates" ]]; then
        printLog "info" "Current job: Validate duplicate media files ..."
        validateDuplicates "$library"
    fi

    if [[ -n "$validate_missing" ]]; then
        if [[ "$library" == "movies" ]]; then
            printLog "info" "Current job: Validate missing media files ..."
            validateCollections "$library"
        elif [[ "$library" == "series" ]]; then
            printLog "info" "Current job: Validate missing media files ..."
            validateEpisodes "$library"
        fi
    fi

    # --------------------------------------------------
    local run_time=$((SECONDS - SCRIPT_TIME))
    printLog "success" "Script executed successfully. Run time: $run_time seconds."
    exit 0
}

main "$@"
