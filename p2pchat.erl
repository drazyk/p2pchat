-module(p2pchat).
-export([start_chat/1,
		start_messenger/2,
		start_receiver/2, 
		printlines/0, 
		printlines_helper/2,
		get_each_contact/3,
		connectTo/1,
		connectTo_helper/3,
		addOnCont/1,
		addOnCont_helper/2,
		offtoall/1,
		offtoall_helper/2, 
		ping/2,
		readlinesContact/4, 
        search_all_contacts/5,
        deployrequest/4,
        send_to_each_contact/5, 
        delCont/1,
        delCont_helper/2]).


start_chat(Prid) ->
	Pid = spawn(p2pchat, start_receiver, [Prid,self()]),
	io:fwrite("Prid: ~p und Pid: ~p und Self: ~p~n", [Prid, Pid, self()]),
	Pid ! {register},
	start_messenger(Prid, Pid).

start_messenger(Prid, Receiver) ->
	io:format("Connection Startet to: ~p~n", [Prid]),
	Term = io:get_line("You:"),
	Test = delete_whitespaces(Term),
	case Test of
		"/exit\n" -> Receiver ! {kill};
		"/C\n" -> 
			printlines(),
			start_messenger(Prid, Receiver);
		"/V\n"->
			Request = io:get_line("Connect to User Nr.: "),
    		WoNl = string:lexemes(Request, [$\n]),
    		Receiver ! {kill},
    		connectTo(WoNl);
		"/P\n" ->
			ping(Prid, Receiver),
			start_messenger(Prid, Receiver);
		"/S\n" ->
			Request = io:get_line("Searching User:"),
			List = string:lexemes(Request, [$\n]),
			ReqContact = lists:nth(1, List),
			io:format("Gesuchter Kontakt: ~p:~p~n", [ReqContact, Receiver]),
			deployrequest( ReqContact ,node(), Prid, Receiver),
			start_messenger(Prid, Receiver);
		"/H\n" ->
			io:fwrite("/H for Help ~n"),
			io:fwrite("/P See who is online~n"),
			io:fwrite("/S Search for a Contact by Username ~n"),
			io:fwrite("/C"),
			io:fwrite("/B for Broadcasting to all Online Users"),
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
			io:format("Ping erhalten ~p~n", [Receiver]),
			{chat, Receiver} ! {pong, Prid},
			addOnCont(Receiver),
			start_receiver(Prid, Messenger);
		{pong, OnlineContact} ->
    		io:fwrite("Pong erhalten: ~p ~n", [OnlineContact]),
			addOnCont(OnlineContact),
			start_receiver(Prid, Messenger);
		{reqPID, SearchingPID, Word} ->
			io:format("Anfrage erhalten: ~p--~p~n ", [Word, SearchingPID]),
			readlinesContact(Word, SearchingPID, Prid, Messenger),
			start_receiver(Prid, Messenger),
			start_messenger(Prid, Messenger);
		{ackreq, PID} ->
			io:format("Antwort erhalten: ~p~n", [PID]),
			file:write_file("Contact.txt", io_lib:fwrite("~s~n", [PID]), [append]),
			start_receiver(Prid, Messenger),
			start_messenger(Prid, Messenger);
		{imoff, Contact} ->
			io:fwrite("Er ist Offline ~n"),
			delCont(Contact),
			start_receiver(Prid, Messenger);
		{kill} ->
			io:format("\ Receiver ended ~n")

	end.
printlines() ->
    Counter = 1,
    {ok, Device} = file:open("Contact.txt", [read]),
    try printlines_helper(Device, Counter)
      after file:close(Device)
    end.
    

printlines_helper(Device, Counter) ->
   case  file:read_line(Device) of 
        {ok, Line} -> 
        Contact = string:lexemes(Line, [$\n]),
        %Falls die letzte Linie ein \n ist
        if
        	Contact =:= [] ->
        		io:fwrite("\n");
        	true ->
        		Disp = lists:nth(1, Contact),
        		io:fwrite("~p.)~p~n", [Counter, Disp]),
        		printlines_helper(Device, Counter+1)
        end;
        
        eof        -> ok
    end.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Allen mitteilen dass ich offline bin
offtoall(MYPID)->
	{ok, Device} = file:open("Contact.txt", [read]),
    try offtoall_helper(Device, MYPID)
      after file:close(Device)
    end.
offtoall_helper(Device, MYPID)->
	case  file:read_line(Device) of
        {ok, Line} -> 
        	NewList = string:lexemes(Line, [$\n]),
        	PID = list_to_atom(lists:concat(NewList)),
			{chat, PID} ! {imoff, MYPID},
      		offtoall_helper(Device, MYPID);

        eof        -> ok
    end.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Füge Online-Kontakt hinzu

addOnCont(Contact) ->
    {ok, Device} = file:open("OnlineContact.txt", [read]),
    try addOnCont_helper(Device, Contact)
      after file:close(Device)
    end.
    

addOnCont_helper(Device, Contact) ->
    %Contact ist ein Atom
   case  file:read_line(Device) of
        {ok, Line} -> 
        Cont = string:lexemes(Line, [$\n]),
        PID = list_to_atom(lists:concat(Cont)),
        Mem = PID =:= Contact,
        if
            Mem =:= false ->
                addOnCont_helper(Device, Contact);

            true ->
            %Muss schauen was hier stattdessen kommt
            %Wahrscheinlich Ping nochmal neu starten
                false            
        end;

        eof        -> 
    file:write_file("OnlineContact.txt", io_lib:fwrite("~s~n", [Contact]), [append])
    end.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Für die Verbindung zu einem neuen Kontakt
connectTo(Int) ->
    Counter = 1,
    {ok, Device} = file:open("Contact.txt", [read]),
    try connectTo_helper(Device, Int, Counter)
      after file:close(Device)
    end.
    

connectTo_helper(Device, Int, Counter) ->
	Convert = string:to_integer(Int),
    Integer = element(1, Convert),
   case  file:read_line(Device) of
        {ok, Line} -> 
        Contact = string:lexemes(Line, [$\n]),
        if
            Counter =:= Integer ->

                PID = list_to_atom(lists:concat(Contact)),
                start_chat(PID);
            true ->
                false
        end,
        connectTo_helper(Device, Int, Counter+1);
        eof        -> ok
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Hab den zweck dieser Funktion vergessen, vielleicht fällt es mir noch ein
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
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

readlinesContact(Word, SearchingPID, Prid, Messenger) ->
	io:fwrite("ICH BIN IM CONTACT search drin, mit dem Wort: ~p:~p~n", [Word, SearchingPID]),
    {ok, Device} = file:open("Contact.txt", [read]),
    io:fwrite("DEVICE: ~p", [Device]),
    try search_all_contacts(Device, Word, SearchingPID, Prid, Messenger)
      after file:close(Device)
    end.
    

search_all_contacts(Device, Word, SearchingPID, Prid, Messenger) ->
   case  file:read_line(Device) of
        {ok, Line} -> 
        io:fwrite("Ich habs in der SUCHE geschafft: ~s~n", [SearchingPID]),
        WTF = string:lexemes(Line, "@" ++ [$\n]),
        io:fwrite("Meine Kontakte: ~p~n", [WTF]),
        Mem = lists:member(Word, WTF),
        	if
        		Mem =:= true ->
					io:fwrite("BIN IM IF DRIN~n"),
                    ReqContact = string:lexemes(Line, [$\n]),
                    PID = list_to_atom(lists:concat(ReqContact)),
                    {chat, SearchingPID} ! {ackreq, PID};
        		true -> 
        			false
        	end,
        	deployrequest(Word, SearchingPID, Prid, Messenger),
        	search_all_contacts(Device, Word, SearchingPID, Prid, Messenger);

        eof        -> start_receiver(Prid, Messenger), 
        			start_messenger(Prid, Messenger)
    end.



deployrequest(Word, SearchingPID, Prid, Messenger) ->
    {ok, Device} = file:open("Contact.txt", [read]),
    try send_to_each_contact(Device, SearchingPID, Word, Prid, Messenger)
      after file:close(Device)
    end.

send_to_each_contact(Device, SearchingPID, Word, Prid, Messenger) ->
   case  file:read_line(Device) of
        {ok, Line} -> 
            NewList = string:lexemes(Line, [$\n]),
            PID = list_to_atom(lists:concat(NewList)),
            io:format("Senden an Kontakt: ~p~n", [PID]),
            {chat, PID} ! {reqPID, SearchingPID, Word},
            send_to_each_contact(Device, SearchingPID, Word, Prid,Messenger);

        eof        -> start_messenger(Prid, Messenger),
        				start_receiver(Prid, Messenger)
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
delCont(Contact) ->
    {ok, Device} = file:open("OnlineContact.txt", [read]),
    try delCont_helper(Device, Contact)
      after file:close(Device)
    end.
    

delCont_helper(Device, Contact) ->
    %Contact ist ein Atom
   case  file:read_line(Device) of
        {ok, Line} -> 
        Cont = string:lexemes(Line, [$\n]),
        PID = list_to_atom(lists:concat(Cont)),
        Mem = PID =:= Contact,
        if
            Mem =:= false ->
              	file:write_file("OnlineContact2.txt", io_lib:fwrite("~s~n", [Cont]), [append]),
                delCont_helper(Device, Contact);

            true ->
            %Muss schauen was hier stattdessen kommt
            %Wahrscheinlich Ping nochmal neu starten
                delCont_helper(Device, Contact)            
        end;

        eof        -> rename()
    end.
removefile() ->
	file:delete("OnlineContact.txt"),
	rename().

rename() ->
	file:rename("OnlineContact2.txt", "OnlineContact.txt").

	
delete_whitespaces(String) -> % does what it says, deletes all whitespaces in a string: "Hello how are you?" -> "Hellohowareyou?" 
	Result = lists:filter(fun(32) -> false; (_) -> true end,String),
	Result.
