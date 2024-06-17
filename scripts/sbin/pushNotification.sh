#!/bin/bash

main() {
    message_head="${1}"
    message_type="${2}"
    message_body="${3}"
    message_wait=${4}

    user_token="uc8joh6vaszypwuvrprbyqfqgpwobb"

    # get app_token
    case ${message_head} in
        certbot)
            app_token="acnh3tbb38s9xmjwt6p4id9zvv2bny"
            ;;
        debian|wakeonlan)
            app_token="asdpr25tei6i5969mcodw1ynsu7jp3"
            ;;
        grafana)
            app_token="ayd4ncfifo8fpe143a82z19p48x4pa"
            ;;
        jdownloader)
            app_token="asfaygindy7fabbe7913avb7je91c8"
            ;;
        nextcloud)
            app_token="acuz3nkj4wbbxtzjdqsfjge4wf1qw9"
            ;;
        overseerr)
            app_token="ajwkxmq1nta7evsy6p59j8atdzbrb6"
            ;;
        imagemaid|kometa)
            app_token="a45ergc1dorqzwcwr2bphps5rqpha6"
            ;;
        restic)
            app_token="a6iygdoubnpy2hq2ggwiou4pxrwbf2"
            ;;
        tautulli)
            app_token="axn99nwdcyft2zibfp7edkesz18zxw"
            ;;
        transmission)
            app_token="ajc6uzgry1kr1oj4q4oademairg6uk"
            ;;
        uptime)
            app_token="ann3bjwzwxxk3js2nqb3itea9pobyc"
            ;;
        *)
            return 1
            ;;
    esac

    # get message_body
    case ${message_type} in
        error)
            message_body="<font color='#BF616A'><b>${message_body}</b></font>"
            ;;
        warn)
            message_body="<font color='#EBCB8B'><b>${message_body}</b></font>"
            ;;
        info)
            message_body="<font color='#5E81AC'><b>${message_body}</b></font>"
            ;;
        okay)
            message_body="${message_body}"
            ;;
        *)
            return 1
            ;;
    esac

    # wait if needed
    if [[ "${message_wait}" ]]; then
        sleep ${message_wait}
    fi

    /usr/bin/curl -s \
        --form-string "token=${app_token}" \
        --form-string "user=${user_token}" \
        --form-string "html=1" \
        --form-string "title=${message_head} on ${HOSTNAME}" \
        --form-string "message=${message_body}" \
        https://api.pushover.net/1/messages.json \
        &> /dev/null
    return $?
}

main "$@"
