-module(p2pchat).
-export([start_chat/1,
		start_messenger/2,
		start_receiver/2, 
		printlines/0, 
		printlines_helper/2,
		printlines2/0,
		printlines_helper2/2,
		get_each_contact/3,
		connectTo/3,
		connectTo_helper/5,
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
        delCont_helper/2, 
        rename/0,
        removefile/0]).


start_chat(Prid) ->
	Pid = spawn(p2pchat, start_receiver, [Prid,self()]),
	Pid ! {register},
	start_messenger(Prid, Pid).

start_messenger(Prid, Receiver) ->
	io:format("Connection Startet to: ~p~n", [Prid]),
	Term = io:get_line("You:"),
	Test = delete_whitespaces(Term),
	case Test of
		"/exit\n" -> 
		offtoall(Prid),
		unregister(chat),
		Receiver ! {kill};
		"/C\n" -> 
			printlines(),
			start_messenger(Prid, Receiver);
		"/V\n"->
			Request = io:get_line("Connect to User Nr.: "),
    		WoNl = string:lexemes(Request, [$\n]),
    		unregister(chat),
    		{chat, node()} ! {kill},
    		connectTo(WoNl, Prid, Receiver);
		"/P\n" ->
			ping(Prid, Receiver),
			start_messenger(Prid, Receiver);
		"/O\n" ->
			printlines2(),
			start_messenger(Prid, Receiver);
		"/S\n" ->
			Request = io:get_line("Searching User:"),
			List = string:lexemes(Request, [$\n]),
			ReqContact = lists:nth(1, List),
			deployrequest(ReqContact ,node(), Prid, Receiver),
			start_messenger(Prid, Receiver);
		"/H\n" ->
			io:fwrite("/H for Help ~n"),
			io:fwrite("/O See who is online~n"),
			io:fwrite("/S Search for a Contact by Username ~n"),
			io:fwrite("/V Connect to user ~n"),
			io:fwrite("/C See my Contactlist ~n"),
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
			io:format(" ~p is Online~n", [lists:nth(1,string:tokens(atom_to_list(Receiver),"@"))]),
			{chat, Receiver} ! {pong, Prid},
			addOnCont(Receiver),
			start_receiver(Prid, Messenger);
		{pong, OnlineContact} ->
			addOnCont(OnlineContact),
			start_receiver(Prid, Messenger);
		{reqPID, SearchingPID, Word} ->
			io:format("Anfrage erhalten: ~p--~p~n ", [Word, SearchingPID]),
			readlinesContact(Word, SearchingPID, Prid, Messenger),
			start_receiver(Prid, Messenger);
		{ackreq, PID} ->
			io:format("Antwort erhalten: ~p~n", [PID]),
			file:write_file("Contact.txt", io_lib:fwrite("~s~n", [PID]), [append]),
			start_receiver(Prid, Messenger);
		{imoff, Contact} ->
			io:format(" ~p is Offline~n", [lists:nth(1,string:tokens(atom_to_list(Contact),"@"))]),
			delCont(Contact),
			start_receiver(Prid, Messenger);
		{kill} ->
			file:delete("OnlineContact.txt"),
			io:format("\ Receiver ended ~n"),
			unregister(chat)

	end.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Zeige mir mein Adressbuch
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
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Zeige mir alle Kontakte die Online sind
printlines2() ->
    Counter = 1,
    {ok, Device} = file:open("OnlineContact.txt", [read]),
    try printlines_helper2(Device, Counter)
      after file:close(Device)
    end.
    

printlines_helper2(Device, Counter) ->
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
	io:fwrite("BIN DAN MAL WEG"),
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
                false            
        end;

        eof        -> 
    file:write_file("OnlineContact.txt", io_lib:fwrite("~s~n", [Contact]), [append])
    end.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Für die Verbindung zu einem neuen Kontakt
connectTo(Int, MasterPID, Receiver) ->
    Counter = 1,
    {ok, Device} = file:open("OnlineContact.txt", [read]),
    try connectTo_helper(Device, Int, Counter, MasterPID, Receiver)
      after file:close(Device)
    end.
    

connectTo_helper(Device, Int, Counter, MasterPID, Receiver) ->
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
            	connectTo_helper(Device, Int, Counter+1, MasterPID, Receiver),
                false
        end;
        eof        -> 
        io:fwrite("Kein Passender Kontakt gefunden ~n"),
        start_messenger(MasterPID, Receiver)
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Zum Pingen, jedoch nicht mehr verwendet
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
    {ok, Device} = file:open("Contact.txt", [read]),
    io:fwrite("DEVICE: ~p", [Device]),
    try search_all_contacts(Device, Word, SearchingPID, Prid, Messenger)
      after file:close(Device)
    end.
    

search_all_contacts(Device, Word, SearchingPID, Prid, Messenger) ->
   case  file:read_line(Device) of
        {ok, Line} -> 
        WTF = string:lexemes(Line, "@" ++ [$\n]),
        Master = string:lexemes(Line, [$\n]),
        MasterPID = list_to_atom(lists:concat(Master)),
        Mem = lists:member(Word, WTF),
        if
          MasterPID =/= SearchingPID ->
          io:fwrite("master ist anders ~n"),
            if
              Mem =:= true ->
                    ReqContact = string:lexemes(Line, [$\n]),
                    PID = list_to_atom(lists:concat(ReqContact)),
                    {chat, SearchingPID} ! {ackreq, PID};
              true ->
                    search_all_contacts(Device, Word, SearchingPID, Prid, Messenger) 
                    
            end;
          true ->
            search_all_contacts(Device, Word, SearchingPID, Prid, Messenger)
        end;
        eof        -> ok
    end.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


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
            if
              PID =/= SearchingPID ->
                {chat, PID} ! {reqPID, SearchingPID, Word};
              true ->
              send_to_each_contact(Device, SearchingPID, Word, Prid, Messenger)
            end,
            
            send_to_each_contact(Device, SearchingPID, Word, Prid, Messenger);
        eof        -> ok
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Aktualisiert den OnlineContact, wenn jemand offline geht
% ein zweites File wird erstellt, alle KOntakte ausser Contact
% werden kopiert und das erste File wird gelöscht
delCont(Contact) ->
	file:write_file("OnlineContact2.txt",<<>> ),
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
                delCont_helper(Device, Contact)            
        end;

        eof        -> rename()
    end.
removefile() ->
	file:delete("OnlineContact.txt"),
	rename().
%das zweite File wird umbenannt
rename() ->
	file:rename("OnlineContact2.txt", "OnlineContact.txt").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	
delete_whitespaces(String) -> % does what it says, deletes all whitespaces in a string: "Hello how are you?" -> "Hellohowareyou?" 
	Result = lists:filter(fun(32) -> false; (_) -> true end,String),
	Result.
