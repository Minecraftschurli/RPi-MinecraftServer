#!/bin/bash
server() {
    screen -Rd minecraft -X stuff "$(echo $@) $(printf '\r')"
}
