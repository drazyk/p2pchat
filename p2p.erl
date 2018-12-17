-module(p2p).
-export([start/0, start_rec/0, printlines2/0, 
    printlines_helper2/2,
    connectTo2/1,
    connectTo_helper2/3,
    pingtoall/1,
    pingtoall_helper/2,
    offtoall/1,
    offtoall_helper/2, readlinesContact/2,
    search_all_contacts/3,
    deployrequest/2,
    send_to_each_contact/3]).
-import (p2pchat, [start_chat/1,
    start_messenger/2,
    start_receiver/2, 
    printlines/0, 
    printlines_helper/2,
    get_each_contact/3,
    connectTo/1,
    connectTo_helper/3, 
    ping/2,
    readlinesContact/4, 
        search_all_contacts/5,
        deployrequest/4,
        send_to_each_contact/5]).


start()->
  io:format( "
  ██╗    ██╗███████╗██╗      ██████╗ ██████╗ ███╗   ███╗███████╗
  ██║    ██║██╔════╝██║     ██╔════╝██╔═══██╗████╗ ████║██╔════╝
  ██║ █╗ ██║█████╗  ██║     ██║     ██║   ██║██╔████╔██║█████╗
  ██║███╗██║██╔══╝  ██║     ██║     ██║   ██║██║╚██╔╝██║██╔══╝
  ╚███╔███╔╝███████╗███████╗╚██████╗╚██████╔╝██║ ╚═╝ ██║███████╗
  ╚══╝╚══╝ ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝

  Hekuran Mulaki, Manuel Drazyk, University of Fribourg, 2018.

  Commands :
      Send a message -> 'Type message' press enter
      See who is online -> /O 
      See your Contactlist -> /C
      start connection to user from Onlinelist -> /V 'number of desired User'
      review commands -> /H
      search for a username -> /S
      Broadcast messages to all OnlineContact -> /B
      quit -> /exit

"),
  Pid = spawn(p2p, start_rec, []),
  Pid ! {register},
  file:write_file("OnlineContact.txt",<<>> ),
  pingtoall(node()),
  start_msg().

start_rec() ->
  receive
    {register} ->
      register(chat, self()),
      start_rec();
      %Wenn eine normale Nachricht eintrifft
    {chat, PridOfMsg, Msg} -> %add case if PridOfMsg is yourself
      io:format("\~s: ~s", 
                  [lists:nth(1,string:tokens(atom_to_list(PridOfMsg),"@")),Msg]), %converts the Prid to a string, to split it by the @ to only get the username and not the IP-adress
      start_rec();
      %Um mittzuteilen dass man Online gegangen ist
    {ping, Receiver} ->
      io:format(" ~p is Online~n", [lists:nth(1,string:tokens(atom_to_list(Receiver),"@"))]),
      {chat, Receiver} ! {pong, node()},
      addOnCont(Receiver),
      start_rec();
    %Bestätigung, dass der Partner auch online ist
    {pong, OnlineContact} ->
      addOnCont(OnlineContact),
      start_rec();
    %Wenn man nach einem Kontakt sucht
    {reqPID, SearchingPID, Word} ->
      io:format("Anfrage erhalten: ~p--~p~n ", [Word, SearchingPID]),
      readlinesContact(Word, SearchingPID),
      start_rec();
    %Kontakt gefunden
    {ackreq, PID} ->
      io:format("Antwort erhalten: ~p~n", [PID]),
      file:write_file("Contact.txt", io_lib:fwrite("~s~n", [PID]), [append]),
      start_rec();
    %Wenn jemand offline geht
    {imoff, Contact} ->
      io:format(" ~p is Offline~n", [lists:nth(1,string:tokens(atom_to_list(Contact),"@"))]),
      delCont(Contact),
      start_rec();
    {kill} -> 
      file:delete("OnlineContact.txt"),
      io:format("\ Receiver ended ~n"),
      unregister(chat)
  end.

start_msg() ->
  Term = io:get_line("Me:"),
  Test = delete_whitespaces(Term),
  case Test of
    "/exit\n" ->
      offtoall(node()), 
      unregister(chat),
      self() ! {kill};
    "/C\n" -> 
      printlines(),
      start_msg();
    "/O\n" ->
      printlines2(),
      start_msg();
    "/S\n" ->
      Request = io:get_line("Searching User:"),
      List = string:lexemes(Request, [$\n]),
      ReqContact = lists:nth(1, List),
      deployrequest(ReqContact ,node()),
      start_msg();
    "/V\n"->
      Request = io:get_line("Connect to User Nr.: "),
        WoNl = string:lexemes(Request, [$\n]),
        unregister(chat),
        {chat, node()} ! {kill},
        connectTo2(WoNl);
    "/H\n" ->
      io:fwrite("/H for Help ~n"),
      io:fwrite("/O See who is online ~n"),
      io:fwrite("/S Search for a Contact by Username ~n"),
      io:fwrite("/C Display Contaclist ~n"),
      io:fwrite("/V Connect to a new user ~n"),
      io:fwrite("/B for Broadcasting to all Online Users ~n"),
      start_msg();
    _ ->
      io:fwrite("Kein Gültiger Command ~nDrücken Sie /H für Hilfe~n"),
      start_msg()
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
%allen mitteilen, dass ich Online bin
pingtoall(MYPID)->
  {ok, Device} = file:open("Contact.txt", [read]),
    try pingtoall_helper(Device, MYPID)
      after file:close(Device)
    end.
pingtoall_helper(Device, MYPID)->
  case  file:read_line(Device) of
        {ok, Line} -> 
          NewList = string:lexemes(Line, [$\n]),
          PID = list_to_atom(lists:concat(NewList)),
      {chat, PID} ! {ping, MYPID},
          pingtoall_helper(Device, MYPID);

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
%Zeige mir alle Kontake aus dem OnlineFile

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
        if
          Contact =:= [] ->
            io:fwrite("\n");
          true ->
            Disp = lists:nth(1, Contact),
            io:fwrite("~p.)~p~n", [Counter, Disp]),
            printlines_helper2(Device, Counter+1)
        end;
        
        eof        -> ok
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Verbinde dich mit einem neuen Kontakt
%Int = Platzierung des Users im File
connectTo2(Int) ->
    Counter = 1,
    {ok, Device} = file:open("OnlineContact.txt", [read]),
    try connectTo_helper2(Device, Int, Counter)
      after file:close(Device)
    end.
    

connectTo_helper2(Device, Int, Counter) ->
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
                connectTo_helper2(Device, Int, Counter+1),
                false
        end;
        eof        -> 
        io:fwrite("Kein Passender Kontakt gefunden ~n"),
        start_msg()
    end.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%An jedem Kontakt den gesuchten User senden
readlinesContact(Word, SearchingPID) ->
    {ok, Device} = file:open("Contact.txt", [read]),
    try search_all_contacts(Device, Word, SearchingPID)
      after file:close(Device)
    end.

search_all_contacts(Device, Word, SearchingPID) ->
   case  file:read_line(Device) of
        {ok, Line} -> 
        WTF = string:lexemes(Line, "@" ++ [$\n]),
        Master = string:lexemes(Line, [$\n]),
        MasterPID = list_to_atom(lists:concat(Master)),
        Mem = lists:member(Word, WTF),
        if
          MasterPID =/= SearchingPID ->
            if
              Mem =:= true ->
                    ReqContact = string:lexemes(Line, [$\n]),
                    PID = list_to_atom(lists:concat(ReqContact)),
                    {chat, SearchingPID} ! {ackreq, PID};
              true ->
                    search_all_contacts(Device, Word, SearchingPID) 
                    
            end;
          true ->
            search_all_contacts(Device, Word, SearchingPID)
        end;
          

        eof        -> deployrequest(Word, SearchingPID)
    end.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Anfrage senden nach suchendem Kontakt
%Überprüft zudem dass es keinen Zyklus gibt, wieder an Master senden.
deployrequest(Word, SearchingPID) ->
    {ok, Device} = file:open("Contact.txt", [read]),
    try send_to_each_contact(Device, SearchingPID, Word)
      after file:close(Device)
    end.

send_to_each_contact(Device, SearchingPID, Word) ->
   case  file:read_line(Device) of
        {ok, Line} -> 
            NewList = string:lexemes(Line, [$\n]),
            PID = list_to_atom(lists:concat(NewList)),
            if
              PID =/= SearchingPID ->
                io:format("Senden an Kontakt: ~p~n", [PID]),
                {chat, PID} ! {reqPID, SearchingPID, Word};
              true ->
              send_to_each_contact(Device, SearchingPID, Word)
            end,
            
            send_to_each_contact(Device, SearchingPID, Word);

        eof        -> ok
    end.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Helperfunction
delete_whitespaces(String) -> % does what it says, deletes all whitespaces in a string: "Hello how are you?" -> "Hellohowareyou?" 
  Result = lists:filter(fun(32) -> false; (_) -> true end,String),
  Result.
