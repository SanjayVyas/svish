# github.com/SanjayVyas

function get_value --description "Get value of a variable which contains another variable name"
    # set name "Angular"; set var name; # get_value var -> Angular
    # Why do we need this? $$var[1] is invalid in fish
    set var (string trim $argv[1])
    set -q $var && echo $$var || echo $var
end

function parse_setting --description "Break a string into a list, keeping quoted parts intact"
    # Thanks github.com/rajch for this gem 👍
    string replace -ra -- "'([^']*)'" '$1' (string match -ra -- "'[^']*'|\S+" $argv)
end

function listify --description "Make a list by splitting on spaces"
    string split ' ' "$argv"
end

function found --description "string_to_find in larger_string"
    # Cosmetic - expect word 'in' as second arg, ignore if it isnt
    [ "$argv[2]" != in ] && set argv[3] $argv[2]
    string match -qer $argv[1] $argv[3]
end

function empty --description "Check if given argument is blank or 0"
    set var $argv[1]
    not set -q $var || string length -q -- $var && [ "$var" = 0 ]
end

function show --description "decide is a user setting is set to show or hide"
    contains (string upper (string trim $argv[1])) Y YES T TRUE
end

function call --description "safe way of calling functions, just in case they are not defined"
    functions -q $argv[1] && $argv[1] $argv[2..-1]
end

function log --description logger
    printf "%s:\t%s\n" (date '+%y-%m-%d %H:%M:%S') "$argv" >>$svp_base_path/logs/svish.log
end

function debug
    echo "$argv" >>$svp_base_path/logs/debug.log
end

function print --description "content fg bg"
    set fg normal
    [ -n $argv[2] ] && set fg $argv[2]

    set bg normal
    [ -n $argv[3] ] && set bg $argv[3]

    set_color $fg -b $bg
    printf "%s" "$argv[1]"
    set_color normal
end

function hex_to_rgb --description "Convert FFFFFF to 255;255;255 for use in ASCII escape sequence"
    set hex (string match --regex '^#?[0-9a-fA-F]{6}$' $argv)
    [ -z $hex ] && echo "" ||
        echo (math 0x(string sub -s 1 -e 2 $hex))";"(math 0x(string sub -s 3 -e 4 $hex))";"(math 0x(string sub -s 5 -e 6 $hex))
end

function color --description "To color a part of a string"
    set text $argv[1]
    set fg (hex_to_rgb $argv[2])
    set bg (hex_to_rgb $argv[3])

    echo -e "\x1b[38;2;"$fg"m\x1b[48;2;"$bg"m"$text"\x1b[0m"
end

function replace_placeholder --description "#placeholder value body"
    string replace "#$argv[1]" "$argv[2]" "$argv[3]"
end

function expand_placeholder --description "#placeholder value body visibility"
    set placeholder (string trim $argv[1])
    set value $argv[2]
    set body $argv[3]
    set visible $argv[4]

    if not show $svish_expand_promplets
        if not empty "$value" && show $visible
            set body (string replace --regex -- "#$placeholder\b" "$value" "$body")
        else
            set body (string replace --regex "\S+#$placeholder *" "" "$body" )
        end
    else
        set count svp_{$placeholder}_count
        set -q $count && set -g $count (math $$count + 1) || set -g $count 1
        set is_it_time (math "$$count % 32")
        if [ $is_it_time -eq 1 -o $is_it_time -gt 3 ]
            if not empty "$value" && show $visible
                set body (string replace --regex -- "#$placeholder *" "$value " "$body")
            else
                set body (string replace --regex ".?#$placeholder *" "" "$body" )
            end
        else if [ $is_it_time -eq 2 ]

            set body (string replace --regex -- "#$placeholder *" "$placeholder $value┊" "$body")

        else if [ $is_it_time -eq 3 ]
            set replacement (string sub -s 1 -e 1 $placeholder) "$value┊"
            set body (string replace --regex -- "#$placeholder *" "$replacement" "$body")
        end
    end

    printf "%s" "$body"
end

function remove_unused_placeholders
    set body (string replace -ar -- '.?#\S*' ' ' "$argv" | tr -s ' ')
    printf "%s" "$body"
end

function lookup --description "Lookup a list like a map 'key:value key:value ...'"
    # $argv[1]      -> key
    # $argv[2..-1]  -> map to lookup the key in
    set found (string match --regex "(?:$argv[1]):(\S+)" $argv[2..-1])
    printf "%s" $found[2]
end

function get_key_value --description "get key value by index from 'key:value key:value...'"

    set index $argv[1]
    set pairs (listify $argv[2])
    printf (listify $pairs[$index])
end

function domain_from_url --description "Extract github.com from http://www.github.com/repo"
    [ -z $argv[1] ] && echo None
    set url (string replace --regex 'https?://(www\.)?' '' $argv[1])
    set url (string replace --regex '^.*@' '' $url)
    set url (string replace --regex '/.*$' '' $url)
    set url (string replace --regex '\.*' ' ' $url)
    string trim $url
end

function md5sum_dir --description "Calculate a single md5sum of all files in a directory"
    find $argv -type f -exec md5sum {} + | sort | md5sum
end
