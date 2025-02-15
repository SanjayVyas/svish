function svish_init --description "Initialize global variables"
    source $g_base_path/core/svish_helpers.fish

    # Load defaults in case user doesn't define them (e.g colours)
    load_defaults

    # Load _svish_state saved in env
    load_state

    # Needed for removing all variables from env at the end
    set -q g_variable_list || set -g g_variable_list

    # Needed to invoke plugin_cleanup
    set -q g_plugin_list || set -g g_plugin_list

    # For quick fire promptlets which don't define their own decorator
    set -q default_decorator || set -g default_decorator

    # Load from cache to save prompt execution time
    svish_load_theme

end

function svish_render_left_prompt --description "Parse prompt lines and render them"

    # No point running the full jingbang if there is no svish.theme
    [ ! -f "$g_base_path/svish.theme" ] && svish_original_fish_prompt && return

    show $svish_blank_line_before_prompt && printf "\n"

    # Parse and sanitize prompt lines
    set left_prompt_lines (set | string match --regex '^svish_left_prompt_[0-9]')
    set parsed_prompt_lines (parse_prompt_lines $left_prompt_lines)
    set parsed_prompt_lines (shift_prompt_to_end $parsed_prompt_lines)

    # Render each prompt line
    for prompt_line in $parsed_prompt_lines
        render_prompt_line $prompt_line
        printf "\n"
    end

end

function svish_render_right_prompt --description "Few segments might go to the right"

    # Parse and render promptlets on the right prompt
    set right_prompt (set|string match --regex '^svish_right_prompt')
    set parsed_prompt_line (parse_prompt_lines $right_prompt)
    render_prompt_line (listify $parsed_prompt_line)

    set -g state_prompt_count (math $state_prompt_count + 1 )
    set -g state_last_pwd (pwd)
    save_state
end

function parse_line --description "Recursive function to expand segments and invoke plugins"
    set prompt_line $argv
    set parsed_line

    # Pick only "segment_xxx" from the line
    for segment in $prompt_line
        if found '^segment_' in $segment
            set name (string replace --regex -- '^segment_' '' $segment)
            set plugin (string replace --regex -- '^segment_' 'svish_' $segment)

            # We need a list of all plugins to clean up later
            set -g g_plugin_list $g_plugin_list $plugin

            # Sometimes plugins may not be in their own dedicated source file, so ignore if file not founds
            source $g_base_path/plugins/$name.svish 2>/dev/null

            # Initialize the plugin and check if it expands to more segment (e.g segment_jsframeworks → segment_node overlap segment_angular)
            call {$plugin}_init
            set nested_segments (call {$plugin}_expand)
            if [ (count $nested_segments) -ne 0 ]

                # If nested segments are found, recursively process them
                set sub_segments (call parse_line $nested_segments)
                set parsed_line $parsed_line $sub_segments
            else
                set parsed_line $parsed_line $segment
            end
        else
            set parsed_line $parsed_line $segment
        end
    end
    echo "$parsed_line"
end

function parse_prompt_lines --description "Validate, expand and sanitize prompt"

    # Pick from theme variables where line starts with svish_left_prompt_
    set prompt_lines $argv
    set parsed_lines

    for line in $prompt_lines
        set parsed_line (parse_line $$line)
        if [ -z "$parsed_lines" ]
            set parsed_lines "$parsed_line"
        else
            set parsed_lines "$parsed_lines" "$parsed_line"
        end
    end

    # We need to result a "list" and not a "string"
    for line in $parsed_lines
        echo $line
    end
end

function render_prompt_line --description "Render each line of promptlets"

    # prompt_line -> segment_directory gap segment_git
    set prompt_line (listify $argv)

    # We need to pre-render all the segments
    # so that we know if some don't return body (e.g git in non repo dir) or periodic promptlets like weather
    # This way we can remove segment/decorator/connectors from the list

    set index 1
    while true

        # We are not sure how many segments will appear in prompt line
        set name $prompt_line[$index]
        [ -z "$name" ] && break

        # Convert segment name to plugin name
        set -g g_current_plugin (string replace 'segment_' 'svish_' $name)
        set body (call $g_current_plugin)
        set body (remove_unused_placeholders $body)
        
        # Some plugins might not yield body due to error or like git not displaying in non-repo
        if [ -z (string trim "$body") ]
            set --erase prompt_line[(math $index +1)]
            set index (math $index + 1)
            continue
        end
        
        # Choose the decorator
        set decorator (string replace 'segment_' '' "$name")_decorator
        [ -z "$$decorator" ] && set decorator default_decorator
        set connector $prompt_line[(math $index + 1)]

        # Build the list of promptlets to be rendered
        set promptlets_list $promptlets_list $body $decorator $connector
        set index (math $index + 2)
    end

    # Decorator elements
    set BEGIN 1
    set FG 2
    set BG 3
    set END 4

    # Sample
    #/  content             decorator               connector       content     decorator               connector   content     decorator
    #/  "/Users/Sanjay"      black light_blue     overlap         master       black light_red      gap         Exit 127     white red 
    #/  -3                  -2                      -1              0           +1                      +2          +3          +4

    # Time to finally render
    set index 1
    while true

        set current_body $promptlets_list[$index]
        [ -z $current_body ] && break

        set current_decorator (get_value $promptlets_list[(math $index + 1)])

        # Break the decorator -> '' 'FFFFFF' 'FF0000' ''
        set current_begin (decorator_element $current_decorator $BEGIN)
        set current_fg (decorator_element $current_decorator $FG)
        set current_bg (decorator_element $current_decorator $BG)
        set current_end (decorator_element $current_decorator $END)

        # If it is not the last segment, get the next segments decorator (index + 2)
        set next_exists no
        if [ (math $index + 3 ) -lt (count $promptlets_list) ]
            set next_exists yes
            set next_decorator $promptlets_list[(math $index + 4)]
            set next_connector $promptlets_list[(math $index + 2)]
            set next_bg (decorator_element $next_decorator $BG)
        end

        # If it is not the first segment, get the prev segments decorator (index - 2)
        set prev_exists no
        if [ (math $index - 3) -ge 0 ]
            set prev_exists yes
            set prev_decorator $promptlets_list[(math $index - 2)]
            set prev_connector $promptlets_list[(math $index - 1)]
            set prev_end (decorator_element $prev_decorator $END)
        end

        # No previous segment, so print this segment's begin block as it is
        if [ $prev_exists = yes ]
            [ $prev_connector = none ] && print $current_begin $current_bg $NORMAL
            [ $prev_connector = gap ] && print $prev_end $NORMAL $current_bg reverse
        else
            print $current_begin $current_bg $NORMAL
        end

        print $current_body $current_fg $current_bg

        if [ $next_exists = yes ]
            [ $next_connector = gap -o $next_connector = none ] && print $current_end $current_bg $NORMAL
            [ $next_connector = overlap ] && print $current_end $current_bg $next_bg
        else
            print $current_end $current_bg $NORMAL
        end

        # Skip to the next content
        set index (math $index + 3)
    end

end

function sanitize_prompt_line --description "Remove misspelt/duplicate/leading/trailing connectors"

    # Don't fall in the trap of empty list
    [ -z "$argv" ] && return

    # Sanitize the list - This function can be skipped for better performance but will break the code if user gives incorrect svish_line_prompt
    set connector_group '(gap|overlap|line|none)'

    # If some idiot (probably me) sends a single string instead of list of segments, break up the string into a list
    set segment_list (listify $argv)

    # 1. Remove all non-sense word except connector_group and segments
    # Pick each word (not the entire string) and check if it is not a connector or a segment, remove it
    set segment_list (string replace --regex "^(?:(?!$connector_group|segment_\S+).)*\$" '' $segment_list)

    # convert the list into a string as remaining string replace need a single string
    set segment_list (echo $segment_list|string collect)

    # 2. Remove leading connector_group [none gap segment_directory gap segment_git] becomes [segment_directory gap segment_git]
    # We do this be removing all characters up to the first segment_xxxxx (non greedily by using *.?)
    set segment_list (string replace --regex '^.*?(\bsegment_\S+\b)' '$1' $segment_list)

    # 2. Remove trailing connector_group [segment_directory gap segment_git none gap none] becomes [segment_directory gap segment_git]
    # Match greedily up to last segment_xxxx and remove whatever is trailing
    set segment_list (string replace --regex '(.*)(\bsegment_\S+\b)(.*)' '$1$2' $segment_list)

    # 3. Remove contiguous connector_group [segment_directory gap none segment_git] becomes [segment_directory gap segment_git]
    # found a pair of connector (gap none or none none etc) and remove the second on, repeat
    while set segment_list (string replace --regex "($connector_group)+(?:$connector_group)" '$1' $segment_list)
    end

    # 4. Add default connector between segments
    # segment_directory segment_git → segment_directory overlap segment_git
    while set segment_list (string replace --regex '(\bsegment_\S+\b)\s+(\bsegment_\S+\b)' '$1 overlap $2' $segment_list)
    end

    printf "%s" "$segment_list"
end

function shift_prompt_to_end --description "We can have only 1 prompt, that too at the end of last line"

    # found out the number of prompt lines we have
    set prompt_list $argv
    set line_count (count $prompt_list)

    # If there are no prompt lines, at least put 'segment_prompt'
    if [ $line_count -eq 0 ]
        echo segment_prompt
    else

        set index 1
        while [ $index -lt $line_count ]
            set line (sanitize_prompt_line (string replace --regex '\bsegment_prompt\b' '' $prompt_list[$index]))
            echo $line
            set index (math $index + 1)
        end

        if found segment_prompt in $prompt_list[$index]
            set line (string replace --regex '\bsegment_prompt\b' '' $prompt_list[$index])'segment_prompt'
            echo $line
        end
    end
end

function svish_original_fish_prompt --description "Just in case we fail and user wants original prompt"
    print (whoami) GREEN NORMAL
    print @(echo $hostname | cut -d'.' -f1)' ' WHITE NORMAL
    print (prompt_pwd) CYAN NORMAL
    print '> ' WHITE NORMAL
end

function svish_load_theme --description "Load user theme or definition unit"
    set theme_name $argv[1]
    # if no theme/unit is provided, load svish.theme
    [ -z "$theme_name" ] && set theme_name "svish.theme"
    if [ -f $g_base_path/$theme_name ]

        # Avoid loading the same theme/unit multiple times
        if not contains $theme_name $g_loaded_themes
            set -g g_loaded_themes $g_loaded_themes $theme_name
            for line in (cat $g_base_path/$theme_name 2>/dev/null)
                # Look for included file
                if string match -qr "^@import " $line
                    set theme_name (string replace '@import ' '' $line)
                    svish_load_theme $theme_name
                end

                # ignore blank limes and those not starting with valid identifiers
                if [ -n $line ] && string match -rq '^[ a-zA-Z]' "$line"
                    set setting (parse_setting $line)
                    set -g $setting

                    # Store all global variables in a list to that we can erase them
                    set -g g_variable_list $g_variable_list $setting[1]
                end
            end
        end
    end
end

function load_theme_cache --description "Load cache if it exists"
    set -q state_checksum || set -g state_checksum

    # Checksum the themes directory so that if any file changes, we recreate the cache
    set checksum (md5sum_dir $g_base_path/svish.theme $g_base_path/themes)
    if [ "$state_checksum" != $checksum ] && [ -f $g_base_path/.cache ]
        for line in (cat $g_base_path/.cache)
            eval $line

            # store the variables in a list so that we can cleanup from env on prompt end
            set -g g_variable_list $g_variable_list $setting[1] (listify $line)[3]
        end
        set state_checksum $checksum
        return 0
    end
    return 1
end

function save_theme_cache --description "Save all theme variables in a cache"
    echo >$g_base_path/.cache
    for var in $g_variable_list
        echo set -g $var \'$$var\' >>$g_base_path/.cache
    end
    set state_checksum (md5sum_dir $g_base_path/svish.theme $g_base_path/themes)
end

function decorator_element --description "Extract different elements of a decorator →  black white "
    # get_value $argv converts directory decorator to "rounded_left black green rounded_right"
    # listify converts "rounded_left black green rounded_right" to  "rounded_left" "black" "green" "rounded_right"
    # get_value converts "black" to "0000"
    set deco_list (listify (get_value $argv[1]))
    get_value $deco_list[$argv[2]]
end

function load_defaults --description "Load defaults in case the user doesn't define them"
    set -g BLACK 000000
    set -g BLUE 0000FF
    set -g CYAN 00FFFF
    set -g FUCHSIA FF00FF
    set -g GRAY 808080
    set -g GREEN 008000
    set -g LIME 00FF00
    set -g MAGENTA FF00FF
    set -g MAROON 800000
    set -g NAVY 000080
    set -g OLIVE 808000
    set -g ORANGE FF781F
    set -g PURPLE 800080
    set -g RED FF0000
    set -g SILVER C0C0C0
    set -g TEAL 008080
    set -g WHITE FFFFFF
    set -g YELLOW FFFF00
    set -g NORMAL normal

    set -g ARROW_LEFT 
    set -g ARROW_RIGHT 
    set -g ROUNDED_LEFT 
    set -g ROUNDED_RIGHT 
    set -g SLANT_EAST_RIGHT 
    set -g SLANT_EAST_LEFT 
    set -g SLANT_WEST_RIGHT 
    set -g SLANT_WEST_LEFT 
    set -g FIRE_LEFT 
    set -g FIRE_RIGHT 
    set -g PIXEL_LEFT 
    set -g PIXEL_RIGHT 
    set -g DIXEL_LEFT 
    set -g DIXEL_RIGHT 
    set -g ARROW_SEPARATOR 
    set -g VERTICAL_SEPARATOR │
    set -g FSLASH_SEPARATOR ╱
    set -g BSLASH_SEPARATOR ╲
    set -g FAT_SEPARATOR ┃
    set -g NO_SEPARATOR ''
    set -g NONE ''
    set -g DOTTED_DIVIDER 

end

function load_state --description "Load state variable from env and break it up into multiple variables"
    for entry in (map_entries $svish_state)
        set key (string match --regex -- '(.*)(?=:.*)' $entry)[2]
        set value (string match --regex -- '(?:.*\:)(.*)' $entry)[2]
        [ -n $key ] && set -g state_{$key} (string trim $value)
    end

    # Some states required by all plugins
    set -q state_prompt_count || set -g state_prompt_count 1
end

function save_state --description "Instead of multiple env variables, save all of them in single svish_state"
    set -g svish_state ""

    for var in (set | string match --regex --entire '^state_')
        set state (string match --regex '^(state_\w+)' $var)[2]
        set name (string match --regex '^state_(\w+)' $var )[2]
        set -g svish_state "$name:$$state $svish_state"
    end
end

function svish_cleanup
    
    # Call all plugin cleanup
    for plugin in $g_plugin_list
        call {$plugin}_cleanup 2>/dev/null
    end

    # Remove all settings variables
    for var in $g_variable_list
        set --erase -g $var 2>/dev/null
    end

    # Remove all global variables
    set global_vars (set | string match --regex '^g_\S+')
    for var in $global_vars
        set -q $var && set --erase -g $var 2>/dev/null
    end

    # Remove all svish_ variables
    set svish_vars (set | string match --regex --entire '_svish_*')
    for var in $svish_vars
        # set --erase $var
    end

    # Remove state variables which have been combined in _svish_state
    for var in (set | string match --regex '^state_\w+\b')
        set -q $var && set --erase -g $var
    end

    # Remove all functions
    set svish_functions (functions | string match --regex '^svish_.*')
    for fn in $svish_functions
        functions --erase $fn
    end
end
