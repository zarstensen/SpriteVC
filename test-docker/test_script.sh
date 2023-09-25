#!/bin/bash

# actually run test
/bin/aseprite/aseprite -b

# now check if tests passed
# the result of all the tests is stored in the last line of the file, as "true" or "false" string

result=$(tail -n 1 /tmp/spritevc/test_result.txt)

if [ "$result" == "true" ]; then
    exit 0
fi

exit 1
