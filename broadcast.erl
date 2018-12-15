-module (broadcast).
-export([init/0, create_nodes/2,broadcast_ring/6]).
%cd("C:/Users/manud/Documents/Concurrent/Project").

init() ->
	Pid_list = [spawn(broadcast, create_nodes, [0, []]), spawn(broadcast, create_nodes, [2, []]), spawn(broadcast, create_nodes, [1, []])],
	erlang:display(Pid_list),
	erlang:send_after(500,self(),{broadcast,prep, self(),null, 0}),	
	broadcast_ring(self(),null,0,Pid_list,1,self()).
	%Pid = spawn(broadcast, broadcast_ring, [self(),0,0,Pid_list,1,self()]),
	%erlang:send_after(500,Pid,{broadcast,prep, self(),null, 0}).
	%self() ! {broadcast,prep, self(),null, 0}.
	%erlang:send_after(500,lists:nth(1,Pid_list),{broadcast,prep, self(),null, 0}).
	
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
											%start_receiver(self(), 0, TransPid, 0),
											ok;
									false ->
										
										case Pid_list_count =:= 1 of %whhich pid return
											true-> erlang:display(lists:flatten(io_lib:format("Die: ~p -> ~p", [self(),RecPid]))),
													RecMaster ! {broadcast, back, TransPid, RecCount},
													start_receiver(self(), 0, RecPid, 1);
											false -> erlang:display(lists:flatten(io_lib:format("Die: ~p -> ~p", [self(),Pid]))),
													RecMaster ! {broadcast, back, TransPid, Count},
													start_receiver(self(), 0, Pid, 1)
										end
										
										
								end
				end;
		{broadcast, back, NewPid, NewCount} ->
				erlang:display(lists:flatten(io_lib:format("Self: ~p -> ~p", [self(),NewPid]))),
				self() ! {broadcast, prep, Pid, Master, NewCount},
				broadcast_ring(Pid, Master, NewCount ,Pid_list,Pid_list_count,NewPid)
				
				
	end.
    
	
	
		
start_receiver(Prid, Messenger, BroadcastPrid, Bot) ->
	receive	
		{register} ->
			register(chat, self()),
			start_receiver(Prid, Messenger, BroadcastPrid, Bot);
		{chat, PridOfMsg, Msg} -> %add case if PridOfMsg is yourself
			io:format("\~s: ~s", 
                  [lists:nth(1,string:tokens(atom_to_list(PridOfMsg),"@")),Msg]), %converts the Prid to a string, to split it by the @ to only get the username and not the IP-adress
			start_receiver(Prid, Messenger, BroadcastPrid, Bot);
		{chatBot, PridOfMsg, Msg} -> %add case if PridOfMsg is yourself
			io:format("\~s: ~s", 
                  [PridOfMsg,Msg]), %converts the Prid to a string, to split it by the @ to only get the username and not the IP-adress
				  case PridOfMsg =:= self() of
					true -> ok;
					false ->
				  case Bot =:= 0 of
					false -> BroadcastPrid ! {chat, Prid, Msg};
					true -> BroadcastPrid ! {chatBot, Prid, Msg}
					end,
			start_receiver(Prid, Messenger, BroadcastPrid, Bot)
			end;
		{kill} ->
			io:format("\ Receiver ended ~n")

	end.

