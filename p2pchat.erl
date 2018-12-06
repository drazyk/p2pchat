-module(p2pchat).
-export([start_chat/1,start_messenger/2,start_receiver/2]).


start_chat(Prid) ->
	Pid = spawn(p2pchat, start_receiver, [Prid,self()]),
	Pid ! {register},
	start_messenger(Prid, Pid).

start_messenger(Prid, Receiver) ->
	Term = io:get_line("You:"),
	case delete_whitespaces(Term) =:= "/exit\n" of
		true -> Receiver ! {kill};
		false ->
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
		{kill} ->
			io:format("\ Receiver ended ~n")

	end.
	
	
delete_whitespaces(String) -> % does what it says, deletes all whitespaces in a string: "Hello how are you?" -> "Hellohowareyou?" 
	Result = lists:filter(fun(32) -> false; (_) -> true end,String),
	Result.