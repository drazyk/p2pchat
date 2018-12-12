-module(p2pchat).
-export([start_chat/1,start_messenger/2,start_receiver/2, readlines/2, get_each_contact/3, ping/2]).


start_chat(Prid) ->
	Pid = spawn(p2pchat, start_receiver, [Prid,self()]),
	Pid ! {register},
	start_messenger(Prid, Pid).

start_messenger(Prid, Receiver) ->
	Term = io:get_line("You:"),
	Test = delete_whitespaces(Term),
	case Test of
		"/exit\n" -> Receiver ! {kill};
		"/C\n" -> 
			readlines(Prid, Receiver),
			start_messenger(Prid, Receiver);
		"/P\n" ->
			ping(Prid, Receiver),
			start_messenger(Prid, Receiver);
		_ ->
			{chat, Prid} ! {chat, node(), Term},
			start_messenger(Prid, Receiver)
	end.
	
	
	
start_receiver(Prid, Messenger) ->
	receive	
		{register} ->
			register(chat, self()),
			start_receiver(Prid, Messenger);
		{chat, PridOfMsg, Msg} -> %add case if PridOfMsg is yourself
			io:format("\~s: ~s", 
                  [lists:nth(1,string:tokens(atom_to_list(PridOfMsg),"@")),Msg]), %converts the Prid to a string, to split it by the @ to only get the username and not the IP-adress
			start_receiver(Prid, Messenger);
		{cont, List} ->
			start_receiver(Prid, Messenger);
		{ping, Receiver} ->
			io:format("Ping erhalten ~n"),
			Receiver ! {pong, Prid},
			start_receiver(Prid, Messenger);
		{pong, OnlineContact} ->
    	io:fwrite("Pong erhalten "),
		file:write_file("OnlineContact.txt", io_lib:fwrite("~s~n", [OnlineContact]), [append]),
		start_receiver(Prid, Messenger),
		start_messenger(Prid, Messenger);
		{kill} ->
			io:format("\ Receiver ended ~n")

	end.

readlines(MasterPID, Receiver) ->
    {ok, Device} = file:open("Contact.txt", [read]),
    try get_each_contact(Device, MasterPID, Receiver)
      after file:close(Device)
    end.

get_each_contact(Device, MasterPID, Receiver) ->
   case  file:read_line(Device) of
        {ok, Line} -> 

        	NewList = string:lexemes(Line, [$\n]),
        	PID = list_to_atom(lists:concat(NewList)),
        	io:fwrite("Meine Liste: ~p~n", [MasterPID]),
			{chat, MasterPID} ! {cont, NewList},

      		get_each_contact(Device, MasterPID, Receiver);

        eof        -> start_messenger(MasterPID, Receiver)
    end.

ping(Prid, Receiver) ->
	readlinesPing(Prid, Receiver).

readlinesPing(MasterPID, Receiver) ->
    {ok, Device} = file:open("Contact.txt", [read]),
    try get_each_contactPing(Device, MasterPID, Receiver)
      after file:close(Device)
    end.

get_each_contactPing(Device, User2, Receiver) ->
   case  file:read_line(Device) of
        {ok, Line} -> 
        	NewList = string:lexemes(Line, [$\n]),
        	PID = list_to_atom(lists:concat(NewList)),
			{chat, PID} ! {ping, Receiver},
      		get_each_contactPing(Device, User2, Receiver);

        eof        -> start_messenger(User2, Receiver)
    end.
	
	
delete_whitespaces(String) -> % does what it says, deletes all whitespaces in a string: "Hello how are you?" -> "Hellohowareyou?" 
	Result = lists:filter(fun(32) -> false; (_) -> true end,String),
	Result.
