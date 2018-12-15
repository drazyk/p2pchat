-module(p2pchat).
-export([start_chat/1,start_messenger/3,start_receiver/3, init/0, create_nodes/2,broadcast_ring/6]).
%cd("C:/Users/manud/Documents/Concurrent/Project").

start_chat(Prid) ->
	erlang:display(node()),
	Pid = spawn(p2pchat, start_receiver, [Prid,self(),0]),
	Pid ! {register},
	start_messenger(Prid, Pid, 0).

start_messenger(Prid, Receiver, Broadcast) ->
	Term = io:get_line("You:"),
	case delete_whitespaces(Term) =:= "/exit\n" of
		true -> Receiver ! {kill};
		false ->
			case delete_whitespaces(Term) =:= "/broadcast\n" of
			true -> Receiver ! {broadcastprep},
					start_messenger(Prid, Receiver, 1);
			false->
				case (Broadcast) =:= 1 of
				true -> 
					Receiver ! {broadcast, node(), Term},
					start_messenger(Prid, Receiver, Broadcast);
				false ->
					{chat, Prid} ! {chat, node(), Term},
					start_messenger(Prid, Receiver, Broadcast)
				end
		end
	end.
	
	
	
start_receiver(Prid, Messenger, BroadcastPrid) ->
	erlang:display(self()),
	receive	
		{register} ->
			register(chat, self()),
			start_receiver(Prid, Messenger, BroadcastPrid);
		{broadcastprep} -> init();
		{chat, PridOfMsg, Msg} -> %add case if PridOfMsg is yourself
			io:format("\~s: ~s", 
                  [lists:nth(1,string:tokens(atom_to_list(PridOfMsg),"@")),Msg]), %converts the Prid to a string, to split it by the @ to only get the username and not the IP-adress
			start_receiver(Prid, Messenger,BroadcastPrid);
			
		{broadcast, PridOfMsg, Msg, First} -> %add case if PridOfMsg is yourself
			io:format("\~s: ~s", 
                  [lists:nth(1,string:tokens(atom_to_list(PridOfMsg),"@")),Msg]), %converts the Prid to a string, to split it by the @ to only get the username and not the IP-adress
				  case PridOfMsg =:= self() of
					true -> case First =:= 1 of
							true -> BroadcastPrid ! {broadcast, PridOfMsg, Msg, 0};
							false -> ok
					end;
					false -> BroadcastPrid ! {broadcast, PridOfMsg, Msg, First}
					end,
			start_receiver(Prid, Messenger,BroadcastPrid);

		{kill} ->
			io:format("\ Receiver ended ~n")

	end.
	
	
delete_whitespaces(String) -> % does what it says, deletes all whitespaces in a string: "Hello how are you?" -> "Hellohowareyou?" 
	Result = lists:filter(fun(32) -> false; (_) -> true end,String),
	Result.
	
	init() ->
	Pid_list = [spawn(broadcast, create_nodes, [0, []]), spawn(broadcast, create_nodes, [2, []]), spawn(broadcast, create_nodes, [1, []])],
	erlang:display(Pid_list),
	erlang:send_after(500,self(),{broadcast,prep, self(),null, 0}),	
	broadcast_ring(self(),null,0,Pid_list,1,self()).
	
create_nodes(NodeCount,Pid_list) ->
		case NodeCount > 0 of
				false ->
						broadcast_ring(self(),0,0,Pid_list,1,self());
				true -> 	
					case Pid_list =:= [] of
						true -> 
							Pid = [spawn(broadcast, create_nodes, [0, []])],
							create_nodes(NodeCount-1,Pid);
						false ->
							Pid = lists:append(Pid_list,[spawn(broadcast, create_nodes, [0, []])]),
							create_nodes(NodeCount-1,Pid)
						end
		end.

broadcast_ring(Pid, Master, Count, Pid_list,  Pid_list_count,TransPid) ->
	receive
		{broadcast, prep, RecPid, RecMaster, RecCount} ->
				case Pid_list_count =< length(Pid_list) of
						true ->
								erlang:display(lists:flatten(io_lib:format("Prep: ~p -> ~p : Weitergabe (~p)", [self(),lists:nth(Pid_list_count, Pid_list),TransPid]))),
								lists:nth(Pid_list_count, Pid_list) ! {broadcast, prep, TransPid, self(), RecCount+1},
								broadcast_ring(RecPid, RecMaster, RecCount, Pid_list, Pid_list_count+1,TransPid);
						false -> 
								erlang:display(lists:flatten(io_lib:format("Back: ~p -> ~p : Weitergabe (~p)", [self(),RecMaster,TransPid]))),
								case RecMaster =:= null of
								
									true -> erlang:display(lists:flatten(io_lib:format("Die: ~p -> ~p", [self(),TransPid]))),
											start_receiver(self(), 0, TransPid),
											ok;
									false ->
										
										case Pid_list_count =:= 1 of %whhich pid return
											true-> erlang:display(lists:flatten(io_lib:format("Die: ~p -> ~p", [self(),RecPid]))),
													RecMaster ! {broadcast, back, TransPid, RecCount},
													start_receiver(self(), 0, RecPid);
											false -> erlang:display(lists:flatten(io_lib:format("Die: ~p -> ~p", [self(),Pid]))),
													RecMaster ! {broadcast, back, TransPid, Count},
													start_receiver(self(), 0, Pid)
										end
										
										
								end
				end;
		{broadcast, back, NewPid, NewCount} ->
				erlang:display(lists:flatten(io_lib:format("Self: ~p -> ~p", [self(),NewPid]))),
				self() ! {broadcast, prep, Pid, Master, NewCount},
				broadcast_ring(Pid, Master, NewCount ,Pid_list,Pid_list_count,NewPid)
				
				
	end.