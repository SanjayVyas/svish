
function svish_init
    svish_load_theme
    set -q svp_prompt_count || set -g svp_prompt_count 0
    set -q svish_variables_list || set -g svish_variables_list
    set -q default_decorator || set -g default_decorator ''
end

function svish_left_prompt --description "Heart of the code, which parses prompt lines and renders them"
    # No point running the full jingbang if there is no svish.theme
    [ ! -f "$svp_base_path/svish.theme" ] && svish_original_fish_prompt && return

    # Cases where themes does not have svish_prompt_line or segment_path is not the last segment of last_line
    shift_prompt_to_end

    # Find how many svish_prompt_lines we have
    # e.g.
    # svish_left_prompt_1 segment_directory overlap segment_git none segment_tips
    # svish_left_prompt_2 segment_exit none segment_prompt
    set svish_prompt_lines (set | grep '^svish_left_prompt_[1-9]' | cut -d ' ' -f1 )

    # Load the plugins and initialize them (don't invoke them right now)
    for line in $svish_prompt_lines

        # overlap segment_directory overlap none segment_git segment_prompt none
        # becomes
        # segment_directory none segment_git overlap segment_prompt
        set prompt_line (listify $$line)

        set segment_list
        for segment_name in $prompt_line

            # Call init for plugins (not connectors)
            if found '^segment_' in $segment_name
                set plugin (string replace 'segment_' '' $segment_name)
                source $svp_base_path/plugins/$plugin.svish
                call svish_{$plugin}_init
            end

            set segment_list $segment_list $segment_name
        end

        # Prepare segment_list per prompt line
        set {$line}_list $segment_list
    end

    # Prepare for launch
     
    show $svish_blank_line_before && printf "\n"
    for prompt_line in $svish_prompt_lines
        set line {$prompt_line}_list
        render_prompt_line $$line
        printf "\n"
    end

    set svp_prompt_count (math $svp_prompt_count + 1)
end

function render_prompt_line --description "Render each line of prompt segments"

    set segment_list $argv

    # We need to pre-render all the segments
    # so that we know if some don't return body (e.g git in non repo dir)
    # This way we can remove segment/decorator/connectors from the list
    set rendered_list
    set plugin_list
    set index 1
    while true

        set name $segment_list[$index]
        [ -z "$name" ] && break

        set plugin (string replace 'segment_' 'svish_' $name)
        set plugin_list $plugin_list $plugin
        set body (call $plugin)

        # Some plugins might not yield body due to error or like git not displaying in non-repo
        if [ -z "$body" ]
            set --erase segment_list[(math $index +1)]
            set index (math $index + 1)
            continue
        end

        set decorator (string replace 'segment_' '' "$name")_decorator
        [ -z "$$decorator" ] && set decorator default_decorator
        set connector $segment_list[(math $index + 1)]

        set rendered_list $rendered_list $body $decorator $connector
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

    set index 1
    while true

        set current_body $rendered_list[$index]
        [ -z $current_body ] && break

        set current_decorator (get_value $rendered_list[(math $index + 1)])

        # Break the decorator -> '' 'FFFFFF' 'FF0000' ''
        set current_begin (decorator_element $current_decorator $BEGIN)
        set current_fg (decorator_element $current_decorator $FG)
        set current_bg (decorator_element $current_decorator $BG)
        set current_end (decorator_element $current_decorator $END)

        # If it is not the last segment, get the next segments decorator (index + 2)
        set next_exists no
        if [ (math $index + 3 ) -lt (count $rendered_list) ]
            set next_exists yes
            set next_decorator $rendered_list[(math $index + 4)]
            set next_connector $rendered_list[(math $index + 2)]
            set next_bg (decorator_element $next_decorator $BG)
        end

        # If it is not the first segment, get the prev segments decorator (index - 2)
        set prev_exists no
        if [ (math $index - 3) -ge 0 ]
            set prev_exists yes
            set prev_decorator $rendered_list[(math $index - 2)]
            set prev_connector $rendered_list[(math $index - 1)]
            set prev_end (decorator_element $prev_decorator $END)
        end

        # No previous segment, so print this segment's begin block as it is
        if [ $prev_exists = yes ]
            [ $prev_connector = none ] && print $current_begin $current_bg black
            [ $prev_connector = gap ] && print $prev_end black $current_bg
        else
            print $current_begin $current_bg black
        end

        print $current_body $current_fg $current_bg

        if [ $next_exists = yes ]
            [ $next_connector = gap -o $next_connector = none ] && print $current_end $current_bg black
            [ $next_connector = overlap ] && print $current_end $current_bg $next_bg
        else
            print $current_end $current_bg black
        end

        # Skip to the next content
        set index (math $index + 3)

        for plugin in $plugin_list
            call {$plugin}_cleanup
        end
    end

end

function svish_right_prompt

    # svish_command_completion_notification

    set segment_list
    for segment_name in $svish_right_prompt

        # Call init for plugins (not connectors)
        if found '^segment_' in $segment_name
            set plugin (string replace 'segment_' '' $segment_name)
            source $svp_base_path/plugins/$plugin.svish
            call svish_{$plugin}_init
        end

        set segment_list $segment_list $segment_name
    end

    render_prompt_line $segment_list
end

function svish_original_fish_prompt --description "Just in case we fail and user wants original prompt"
    print (whoami) green normal
    print @(echo $hostname | cut -d'.' -f1)' ' white normal
    print (prompt_pwd) cyan normal
    print '> ' white normal
end

function svish_cleanup

    # Erase all settings loaded from themes
    for var in $svish_variables_list
        set -q $var && set --erase -g $var
    end

    # Erase all settings defined by plugins
    for var in (set | grep '^svish_'| cut -d ' ' -f1)
        set --erase -g $var
    end

    set --erase -g svp_loaded_themes

    for fn in (functions | grep '^svish_')
        functions -e $fn
    end

end
