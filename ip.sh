#!/bin/bash
read -p 'Username: ' uservar
echo $(hostname -I)
erl -name $uservar@$(hostname -I) -setcookie chat
