-module(brp2pchat).
-export([start_chat/0,start_messenger/3,start_receiver/4, init/0, create_nodes/2,broadcast_ring/6,waiting_nodes/0,create_connections/2]).
%cd("C:/Users/manud/Documents/Concurrent/Project").

start_chat() ->
	Pid = spawn(brp2pchat, start_receiver, [node(),self(),0, null]),
	Pid ! {register},
	start_messenger(node(), Pid, 0).

start_messenger(Prid, Receiver, Broadcast) ->
	Term = io:get_line("You:"),
	case delete_whitespaces(Term) =:= "/exit\n" of
		true -> unregister(chat),
				Receiver ! {kill};
		false ->
			case delete_whitespaces(Term) =:= "/broadcast\n" of
			true -> Receiver ! {broadcastprep},
					start_messenger(Prid, Receiver, 1);
			false-> 
				case delete_whitespaces(Term) =:= "/brkill\n" of
					true -> 
							Receiver ! {broadcast, redo, Receiver, 1, []},
							start_messenger(Prid, Receiver, 1);
					false ->
				case (Broadcast) =:= 1 of
				true -> 
					Receiver ! {broadcast, cast, node(), Term, Receiver, 1, 0},
					start_messenger(Prid, Receiver, Broadcast);
				false ->
					{chat, Prid} ! {chat, node(), Term},
					start_messenger(Prid, Receiver, Broadcast)
				end
				end
		end
	end.
	
	kill_processes(NodeCount, Full_Pid_List, Pid_list) ->
			case NodeCount > 0 of
				false -> erlang:send_after(500,self(),{broadcast,prep, self(),null, 0,1}),	
						broadcast_ring(self(),null,0,Pid_list,1,self());
				true -> lists:nth(rand:uniform(length(Full_Pid_List)),Full_Pid_List) ! {kill},
						kill_processes(NodeCount-1, Full_Pid_List, Pid_list)
			end.
			
	

	
start_receiver(Prid, Messenger, BroadcastPrid, Pid_list) ->
	receive	
		{register} ->
			register(chat, self()),
			start_receiver(Prid, Messenger, BroadcastPrid, Pid_list);
		{broadcastprep} -> init();
		{chat, PridOfMsg, Msg} -> %add case if PridOfMsg is yourself
			io:format("\~s: ~s", 
                  [lists:nth(1,string:tokens(atom_to_list(PridOfMsg),"@")),Msg]), %converts the Prid to a string, to split it by the @ to only get the username and not the IP-adress
			start_receiver(Prid, Messenger,BroadcastPrid, Pid_list);
			
		{broadcast, cast, PridOfMsg, Msg, ProcOfMsg, First, Counter} -> %add case if PridOfMsg is yourself
				  case ProcOfMsg =:= self() of
					true -> case First =:= 1 of
							true ->  BroadcastPrid ! {broadcast, cast, PridOfMsg, Msg, ProcOfMsg, 0, Counter+1};
							false -> ok
					end;
					false ->io:format("\ (~p) ~s: ~s ", 
                  [ Counter,lists:nth(1,string:tokens(atom_to_list(PridOfMsg),"@")), Msg]), %converts the Prid to a string, to split it by the @ to only get the username and not the IP-adress
					BroadcastPrid ! {broadcast, cast, PridOfMsg, Msg, ProcOfMsg, First, Counter+1}
					end,
			start_receiver(Prid, Messenger,BroadcastPrid, Pid_list);

		{broadcast, prep, RecPid, RecMaster, RecCount, FromBack} ->
				erlang:display("Back3"),
				RecMaster ! {broadcast, back, RecPid, RecCount},
				start_receiver(Prid, Messenger,BroadcastPrid, Pid_list);
		{broadcast, redo, ProcOfMsg, First, Full_Pid_List} -> 
				case ProcOfMsg =:= self() of
					true -> 
						case First =:= 1 of
							true -> 
									BroadcastPrid ! {broadcast, redo, ProcOfMsg, 0, []},
									 start_receiver(Prid, Messenger, BroadcastPrid, Pid_list);
							false -> erlang:display(Full_Pid_List),
									kill_processes(10, Full_Pid_List, Pid_list)
									
						end;
					false ->
						BroadcastPrid ! {broadcast, redo, ProcOfMsg, First, lists:append(Full_Pid_List, [self()])},
						broadcast_ring(self(),0,0,Pid_list,1,self())
				end,
			start_receiver(Prid, Messenger,BroadcastPrid, Pid_list);
		{kill} ->
			io:format("\ Receiver ended ~n")

	end.
	
	
delete_whitespaces(String) -> % does what it says, deletes all whitespaces in a string: "Hello how are you?" -> "Hellohowareyou?" 
	Result = lists:filter(fun(32) -> false; (_) -> true end,String),
	Result.
	
	init() ->
	Count = 100,
	Nodes = create_nodes(Count, []),
	create_connections(Nodes,Count).

	
create_nodes(NodeCount,Pid_list) ->
		case NodeCount > 0 of
				false -> Pid_list;
				true -> 	
					case Pid_list =:= [] of
						true -> 
							Pid = [spawn(brp2pchat, waiting_nodes, [])],
							create_nodes(NodeCount-1,Pid);
						false ->
							Pid = lists:append(Pid_list,[spawn(brp2pchat, waiting_nodes, [])]),
							create_nodes(NodeCount-1,Pid)
						end
		end.
		
		waiting_nodes() ->
			receive
				{wait_list, Pid_list} ->
					erlang:display(lists:flatten(io_lib:format("Connection: ~p -> ~p ", [self(),Pid_list]))),
					broadcast_ring(self(),0,0,Pid_list,1,self())
			end.
			
	create_connections(Pid_list, Count) ->
		case Count > 0 of
				false -> erlang:send_after(500,self(),{broadcast,prep, self(),null, 0,1}),	
						broadcast_ring(self(),null,0, [lists:nth(random_int(length(Pid_list),Count), Pid_list), lists:nth(random_int(length(Pid_list),Count), Pid_list), lists:nth(random_int(length(Pid_list),Count), Pid_list)],1,self());
				true ->
					lists:nth(Count, Pid_list) ! {wait_list, [lists:nth(random_int(length(Pid_list),Count), Pid_list), lists:nth(random_int(length(Pid_list),Count), Pid_list), lists:nth(random_int(length(Pid_list),Count), Pid_list)]},
					create_connections(Pid_list, Count-1)
		end.
	
random_int(Counter, Exception) ->
	Random_proposal = rand:uniform(Counter),
	case Random_proposal =:= Exception of
		true -> Random_Num = random_int(Counter, Exception);
		false -> Random_Num = Random_proposal,
				Random_Num
	end.
			
broadcast_ring(Pid, Master, Count, Pid_list,  Pid_list_count,TransPid) ->
	receive
		{broadcast, prep, RecPid, RecMaster, RecCount, FromBack} ->
				case Pid_list_count =< length(Pid_list) of
						true ->
								case Pid =:= TransPid of  %true then pid has to be updated
									true ->
										case FromBack =:= 0 of 
											true ->
												case Master =:= null of %the first node has always Pid = TransPid until the very end
													true ->
														erlang:display("Back2"),
														RecMaster ! {broadcast, back, RecPid, RecCount},
														broadcast_ring(Pid, Master, Count, Pid_list, Pid_list_count,TransPid);
													false ->
														erlang:display(lists:flatten(io_lib:format("Prep2: ~p -> ~p : Weitergabe (~p)", [self(),lists:nth(Pid_list_count, Pid_list),TransPid]))),
														lists:nth(Pid_list_count, Pid_list) ! {broadcast, prep, TransPid, self(), RecCount+1, 0},
														broadcast_ring(RecPid, RecMaster, RecCount, Pid_list, Pid_list_count+1,TransPid)
												end;
											false ->
														erlang:display(lists:flatten(io_lib:format("Prep3: ~p -> ~p : Weitergabe (~p)", [self(),lists:nth(Pid_list_count, Pid_list),TransPid]))),
														lists:nth(Pid_list_count, Pid_list) ! {broadcast, prep, TransPid, self(), RecCount+1, 0},
														broadcast_ring(RecPid, RecMaster, RecCount, Pid_list, Pid_list_count+1,TransPid)
											end;	
									false ->
										case FromBack =:= 1 of 
											true -> erlang:display(lists:flatten(io_lib:format("Prep: ~p -> ~p : Weitergabe (~p)", [self(),lists:nth(Pid_list_count, Pid_list),TransPid]))),
													lists:nth(Pid_list_count, Pid_list) ! {broadcast, prep, TransPid, self(), RecCount+1, 0},
													broadcast_ring(Pid, Master, Count, Pid_list, Pid_list_count+1,TransPid);
											false ->
													erlang:display("Back"),
													RecMaster ! {broadcast, back, RecPid, RecCount},
													broadcast_ring(Pid, Master, Count, Pid_list, Pid_list_count,TransPid)
										end
								end;
						false -> 
								case FromBack =:= 1 of 
									false -> erlang:display("Back4"),
													RecMaster ! {broadcast, back, RecPid, RecCount},
													broadcast_ring(Pid, Master, Count, Pid_list, Pid_list_count,TransPid);
									true ->
								erlang:display(lists:flatten(io_lib:format("Back: ~p -> ~p : Weitergabe (~p)", [self(),RecMaster,TransPid]))),
								case RecMaster =:= null of
									true -> erlang:display(lists:flatten(io_lib:format("Die: ~p -> ~p", [self(),TransPid]))),
											start_receiver(self(), 0, TransPid, Pid_list);
									false ->
										case Pid_list_count =:= 1 of %whhich pid return
											true-> erlang:display(lists:flatten(io_lib:format("Die: ~p -> ~p", [self(),RecPid]))),
													RecMaster ! {broadcast, back, TransPid, RecCount},
													start_receiver(self(), 0, RecPid, Pid_list);
											false -> erlang:display(lists:flatten(io_lib:format("Die: ~p -> ~p", [self(),Pid]))),
													RecMaster ! {broadcast, back, TransPid, Count},
													
													start_receiver(self(), 0, Pid, Pid_list)
										end
										
										
								end
						end
				end;
		{broadcast, back, NewPid, NewCount} ->
				erlang:display(lists:flatten(io_lib:format("Self: ~p -> ~p ", [self(),NewPid]))),
				self() ! {broadcast, prep, NewPid, Master, NewCount, 1},
				broadcast_ring(Pid, Master, NewCount ,Pid_list,Pid_list_count,NewPid);
		{kill} -> ok
				
				
	end.