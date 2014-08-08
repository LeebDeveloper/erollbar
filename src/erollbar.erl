-module(erollbar).

-type access_token() :: binary().
-type ms() :: non_neg_integer().
-type filter() :: fun((module()) -> ok | drop).
-type opt() :: {environment, binary()}|
               {platform, binary()}|
               {batch_max, pos_integer()}|
               {time_max, ms()}|
               {endpoint, binary()}|
               {host, binary()}|
               {root, binary()}|
               {branch, binary()}|
               {sha, binary()}|
               {filter, filter()}|
               {http_timeout, non_neg_integer()}|
               send_args.
-type opts() :: [opt()].
-export_type([access_token/0
             ,opt/0
             ,opts/0
             ,filter/0
             ,ms/0]).
-export([start/1
        ,start/2
        ,stop/0
        ,default_filter/1]).

-spec start(access_token()) -> ok.
start(AccessToken) ->
    start(AccessToken, []).

-spec start(access_token(), opts()) -> ok.
start(AccessToken, Opts) ->
    Opts1 = set_defaults([{environment, <<"prod">>}
                         ,{platform, <<"beam">>}
                         ,{batch_max, config(batch_max)}
                         ,{endpoint, config(endpoint)}
                         ,{host, hostname()}
                         ,{filter, fun default_filter/1}
                         ,{http_timeout, config(http_timeout)}
                         ], Opts),
    Opts2 = validate_opts(Opts1, []),
    ok = error_logger:add_report_handler(erollbar_handler, [AccessToken, Opts2]).

-spec stop() -> ok | term() | {'EXIT', term()}.
stop() ->
    error_logger:delete_report_handler(erollbar_handler).

%% Internal
set_defaults([], Opts) ->
    Opts;
set_defaults([{Key, _}=Pair|Rest], Opts) ->
    case lists:keymember(Key, 1, Opts) of
        true ->
            set_defaults(Rest, Opts);
        false ->
            set_defaults(Rest, [Pair | Opts])
    end.

validate_opts([], Retval) ->
    Retval;
validate_opts([{Key, _}=Pair|Rest], Retval) ->
    case lists:member(Key, [environment, batch_max, host, endpoint, root, branch,
                            sha, platform, time_max, filter, http_timeout]) of
        true ->
            validate_opts(Rest, [Pair | Retval]);
        false ->
            throw({invalid_config, Key})
    end;
validate_opts([Opt|Rest], Retval) ->
    case lists:member(Opt, [send_args]) of
        true ->
            validate_opts(Rest, [Opt | Retval]);
        false ->
            throw({invalid_config, Opt})
    end.

hostname() ->
    {ok, Hostname} = inet:gethostname(),
    list_to_binary(Hostname).

%% The default filter filters out messages that are also sent as crash_reports, this
%% is to prevent double reporting. It's available as an export and c,an be used in
%% other filters.
default_filter([error, "** Generic server ~p terminating \n** Last message" ++
                    " in was ~p~n** When Server state == ~p~n**" ++
                    " Reason for termination == ~n** ~p~n", _Data]) ->
    drop;
default_filter(_) ->
    ok.

config(Key) ->
    case application:get_env(erollbar, Key) of
        {ok, Val} ->
            Val;
        _ ->
            throw({missing_config, Key})
    end.
