function map_get --description "Given a key, return value"
    set key $argv[1]
    set map "$argv[2..-1]"

    # \b$key:   -> key must begin on word boundary and followed by : which can have spaces before the : 
    # ?<value>  -> capture the value of the key
    # .*?       -> capture non-greedy, i.e up to next key: first, else up to end of line($)
    # (\S+:|$)  -> Next should be either the next key: or end of line

    # This ensures that we pick values which can contain spaces
    # e.g "weather   : max 20 min 5 wind 12 sunrise: 6.15"

    string match --regex --quiet '\b'$key'\s*:\s*(?<value>.*?)(\w+\s*:\s*|$)' $map
    echo $value
end

function map_put --description "Set a key:value, replace if existing"
    set key $argv[1]
    set value $argv[2]
    set map $argv[3..-1]

    # Search for key at word boundary and maybe followed by spaces and finally :
    if string match --regex --quiet '\b'$key'\s*:' $map

        # If found, replace it with new pair of key, value
        string replace --regex --quiet '\b'$key'\s*:.*?(?=\b\w+\s*:)' $key:$value' ' $map
    else
        # Key not found? Add key:value to the end
        echo  $map' '$key:$value' '
    end
end

function map_keys --description "Return all keys as a list"

    # keys begin at word boundary \bkeys
    # Create a named group ?<keys>
    # Key must be word char - alpha, numeric or underscore
    string match --regex --all --quiet "\b(?<keys>\w+?)\s*:" $argv

    # return a list of keys
    echo $keys
end

function map_remove --description "Remove a key from the map"
    set key $argv[1]
    set map $argv[2..-1]
    string replace --regex '\b'$key'\s*:.*?(?=\b\w+\s*:)' '' $map
end

function map_index --description "Return key:value pair by index (starts 1)"
    set index $argv[1]
    set map $argv[2..-1]

    # key:value starts with word boundary '\b', has word '\w+' followed by any chars '.*' (including spaces) take shortest '? match'
    # Must be followed by '?=' either the next key '\b\w+:' or end of line '$''
    string match --regex --all --quiet '(?<pair>\b\w+\s*+:.*?)(?=(\b\w+\s*:|$))' $map
    if [ $index -le 0 ]
        for value in $pair
            echo $value
        end
    else
        echo $pair[$index]
    end
end
