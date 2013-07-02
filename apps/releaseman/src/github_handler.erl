-module(github_handler).
-compile(export_all).
-behaviour(cowboy_http_handler).
-export([init/3, handle/2, terminate/3]).

init(_Transport, Req, []) -> {ok, Req, undefined}.

handle(Req, State) ->
    {Params,NewReq} = cowboy_req:path(Req),
    Path = lists:reverse(string:tokens(binary_to_list(Params),"/")),
    [Repo,User|Rest] = Path,
    spawn(fun() -> build(Repo,User) end),
    HTML = <<"<h1>202 Project Started to Build</h1>">>,
    {ok, Req3} = cowboy_req:reply(202, [], HTML, NewReq),
    {ok, Req3, State}.

terminate(_Reason, _Req, _State) -> ok.

cmd({Id,Docroot,Buildlogs,LogFolder},No,List) ->
    Message = os:cmd(["cd ",Docroot," && bash -c \"",List,"\""]),
    FileName = binary_to_list(base64:encode(lists:flatten([integer_to_list(No)," ",List]))),
    File = lists:flatten([Buildlogs,"/",LogFolder,"/",FileName]),
    error_logger:info_msg("Command: ~p",[List]),
    error_logger:info_msg("Output: ~p",[Message]),
    file:write_file(File,Message).

build(Repo,User) ->
    Id = User ++ "-" ++ Repo,
    Docroot = "repos/" ++ Id,
    Buildlogs = "buildlogs/"++ Id,
    error_logger:info_msg("Hook worker called ~p",[Docroot]),
    {{Y,M,D},{H,Min,S}} = calendar:now_to_datetime(now()),
    LogFolder = io_lib:format("~p-~p-~p ~p:~p:~p",[Y,M,D,H,Min,S]),
    os:cmd(["mkdir -p \"",Docroot,"\""]),
    os:cmd(["mkdir -p \"",Buildlogs,"/",LogFolder,"\""]),
    Ctx = {Id,Docroot,Buildlogs,LogFolder},
    case os:cmd(["ls ",Docroot]) of
        [] -> os:cmd(["git clone git@github.com:",User,"/",Repo,".git ",Docroot]);
        _ -> ok end,
    Script = ["git pull","rebar get-deps","rebar compile","./stop.sh","./release.sh","./styles.sh","./javascript.sh","./start.sh"],
    [ cmd(Ctx,No,lists:nth(No,Script)) || No <- lists:seq(1,length(Script)) ].
