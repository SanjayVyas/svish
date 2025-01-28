
function svish_load_theme --description "Load user theme or definition unit"
    set theme_name $arg[1]

    # if no theme/unit is provided, load svish.theme
    set theme_name ([ -z $argv[1] ] && echo "svish.theme" || echo $argv[1])

    if [ -f $svp_base_path/$theme_name ]

        # Avoid loading the same theme/unit multiple times
        if not contains $theme_name $svp_loaded_themes
            set -g svp_loaded_themes $svp_loaded_themes $theme_name

            for line in (cat $svp_base_path/$theme_name 2>/dev/null)

                # Look for included file
                if string match -qr "^@import " $line
                    set theme_name (string replace '@import ' '' $line)
                    svish_load_theme $theme_name
                end

                # ignore blank limes and those not starting with valid identifiers
                if [ -n $line ] && string match -rq '^[ a-zA-Z]' "$line"
                    set setting (listify $line)
                    set -g $setting

                    # Store all global variables in a list to that we can erase them
                    set -g svish_variables_list $svish_variables_list $setting[1]
                end
            end
        end
    end
end

function sanitize_prompt_line

    # If some idiot (probably me) sends a single string instead of list of segments
    set segment_list (listify $argv)

    # Don't fall in the trap of empty list
    empty $segment_list && return

    set connector_set gap overlap line none

    # Sanitize the list - These can be skipped for better performance but will break the code if user gives incorrect svish_line_prompt

    # 1. Remove leading connectors (overlap, gap, none etc)
    # gap gap segment_directory overlap segment_git → segment_directory overlap segment_git
    while not empty $segment_list && not found "^segment_" in $segment_list[1]
        set segment_list $segment_list[2..-1] # Keep 2nd element to last element
    end
    # 2. Remove trailing connectors
    # segment_directory overlap segment_git gap gap → segment_directory overlap segment_git
    while not empty $segment_list && not found "^segment_" in $segment_list[-1]
        set segment_list $segment_list[1..-2] # Keep 1st element to 2nd last element
    end

    # 3. Remove incorrect connectors
    # segment_directory pag segment_git  → segment_directory segment_git
    set index 1
    while [ $index -lt (count $segment_list) ]
        if not found "^segment_" in $segment_list[$index] && not contains $segment_list[$index] in $connector_set
            set --erase segment_list[$index]
        else
            set index (math $index + 1)
        end
    end

    # 3. Remove contiguous connectors
    # segment_directory gap gap segment_git → segment_directory gap segment_git
    
    set index 1
    while [ $index -lt (count $segment_list) ]
        if found "^segment_" in $segment_list[$index]
            set index (math $index + 1)
            continue
        end

        while not found "^segment_" in $segment_list[ (math $index + 1) ]
            set -e segment_list[$index]
        end
        set index (math $index + 1)
    end

    # 4. Add default connector between segments
    # segment_directory segment_git → segment_directory overlap segment_git
    set index 1
    while [ $index -lt (count $segment_list) ]
        if found "^segment_" in $segment_list[ (math $index + 1)]
            set segment_list $segment_list[1..$index] overlap $segment_list[(math $index+1)..-1]
        end
        set index (math $index + 2)
    end

    echo (listify $segment_list)
end

function shift_prompt_to_end

    # Find out the number of prompt lines we have
    set prompt_lines (set | grep -o ^svish_left_prompt_[1-9])
    set line_count (count $prompt_lines)
    # if there are no defined prompt lines, set segment_prompt as the first one
    if [ $line_count -eq 0 ]
        set -g svish_left_prompt_1 segment_prompt
    else

        # remove any segment_prompt from all but last line
        set index 1
        while [ $index -lt $line_count ]
            set current_line svish_left_prompt_{$index}
            set $current_line (sanitize_prompt_line (string replace 'segment_prompt' '' $$current_line ))
            set index (math $index + 1)
        end

        # Put segment_prompt as the last segment
        set current_line svish_left_prompt_{$index}
        set $current_line (string replace 'segment_prompt' '' $$current_line ) " segment_prompt"
        set $current_line (sanitize_prompt_line $$current_line)
    end
end

function shorten_directory_path
    set path (string replace $HOME '~' $argv)
    set pathlets (string trim (string split '/' $path))
    set dir $pathlets[-1]
    set --erase pathlets[-1]

    set body ''
    for each in $pathlets
        set how_many ( [ (string sub -s 1 -e 1 $each) = "." ] && echo 2 || echo 1)
        set body $body(string sub -s 1 -e $how_many $each)'/'
    end
    set body $body$dir
    printf "%s" "$body"
end

function svish_command_completion_notification

    if not contains $command_name vi bash
        set execution_duration (math $CMD_DURATION / 1000)
        set excluded_commands_list (cat ./excluded commands 2>/dev/null)
        set command_name (history | head -1 | cut -d ' ' -f1)

        set exit_status ( [ $exit_value -gt 0 ] && echo "⚠️ $exit_value" ||  echo  "👍")
        if [ $execution_duration -gt 30 ]
            terminal-notifier -title "$command_name Completed $exit_status" -message "The command took $execution_duration seconds" -sound Glass
        end
    end
end

function decorator_element --description "Extract different elements of a decorator →  black white "
    # get_value $argv converts directory decorator to "rounded_left black green rounded_right"
    # listify converts "rounded_left black green rounded_right" to  "rounded_left" "black" "green" "rounded_right"
    # get_value converts "black" to "0000"
    set deco_list (listify (get_value $argv[1]))
    get_value $deco_list[$argv[2]]
end

function get_value --description "Get value of a variable which contains another variable name"
    set var (string trim $argv[1])
    set -q $var && echo $$var || echo $var
end

function listify --description "Break a string into list, keeping quoted parts intact"
    # Thanks github.com/rajch for this gem 👍
    string replace -ra -- "'([^']*)'" '$1' (string match -ra -- "'[^']*'|\S+" $argv)
end

function found --description "string_to_find in larger_string"
    [ "$argv[2]" != in ] && set argv[3] $argv[2]
    string match -qer $argv[1] $argv[3]
end

function empty --description "Check if given argument is blank"
    set var $argv[1]
    not set -q $var || string length -q -- $var && [ "$var" = 0 ]
end

function show --description "decide is a user setting is set to show or hide"
    contains (string upper (string trim $argv[1])) "Y" "YES" "YEAH" "T" "TRUE" "SURE"
end

function call --description "safe way of calling functions, just in case they are not defined"
    functions -q $argv && $argv
end

function log --description logger
    printf "%s:\t%s\n" (date '+%y-%m-%d %H:%M:%S') "$argv" >>$svp_base_path/logs/svish.log
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

function hex_to_rgb
    set hex (string match -r '^#?[0-9a-fA-F]{6}$' $argv)
    [ -z $hex ] && echo "" ||
        echo (math 0x(string sub -s 1 -e 2 $hex))";"(math 0x(string sub -s 3 -e 4 $hex))";"(math 0x(string sub -s 5 -e 6 $hex))
end

function color
    set text $argv[1]
    set fg (hex_to_rgb $argv[2])
    set bg (hex_to_rgb $argv[3])

    echo -e "\x1b[38;2;"$fg"m\x1b[48;2;"$bg"m"$text"\x1b[0m"
end

function replace_placeholder --description "#placeholder value body"
    string replace "#$argv[1]" "$argv[2]" "$argv[3]"
end

function expanded_placeholder --description "#placeholder value body visibility"

    set placeholder (string trim $argv[1])
    set value $argv[2]
    set body $argv[3]
    set visible $argv[4]

    set count svp_{$placeholder}_count
    set -q $count && set -g $count (math $$count + 1) || set -g $count 1

    set is_it_time (math "$$count % 32")
    if [ $is_it_time -eq 1 -o $is_it_time -gt 3 ]
        if has_value "$value" && show $visible
            set body (string replace -r -- "#$placeholder *" "$value " "$body")
        else
            set body (string replace -r ".?#$placeholder *" "" $body )
        end
    else if [ $is_it_time -eq 2 ]

        set body (string replace -r -- "#$placeholder *" "$placeholder $value ┊" "$body")

    else if [ $is_it_time -eq 3 ]
        set replacement (string sub -s 1 -e1 $placeholder) "$value ┊"

        set body (string replace -r -- "#$placeholder *" "$replacement" "$body")
    end

    printf "%s" "$body"
end

function remove_unused_placeholders
    string replace -ar -- '#.+\s*' ' ' $argv | tr -s ' '
end

function has_value
    set var $argv[1]
    if not set -q $var || string length -q -- $var && [ "$var" = 0 ]
        return 1
    end
    return 0
end

function domain_from_url
    [ -z $argv[1] ] && echo None
    set url (string replace -r 'https?://(www\.)?' '' $argv[1])
    set url (string replace -r '^.*@' '' $url)
    set url (string replace -r '/.*$' '' $url)
    set url (string replace -r '\.*' ' ' $url)
    echo $url | tr -d ' '
end
