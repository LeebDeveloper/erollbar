-module(erollbar).

-type access_token() :: binary().
-type ms() :: non_neg_integer().
-type opt() :: {environment, binary()}|
               {platform, binary()}|
               {batch_max, pos_integer()}|
               {time_max, ms()}|
               {rpm_max, non_neg_integer()}|
               {endpoint, binary()}|
               {host, binary()}|
               {root, binary()}|
               {branch, binary()}|
               {sha, binary()}|
               {http_timeout, non_neg_integer()}|
               {report_handlers, [erollbar_handlers:handler()]}|
               send_args.
-type opts() :: [opt()].
-export_type([opt/0
             ,opts/0
             ,ms/0
             ,access_token/0]).

-export([start/1
        ,start/2
        ,stop/0]).

-spec start(access_token()) -> ok.
start(AccessToken) ->
    start(AccessToken, []).

-spec start(access_token(), opts()) -> ok.
start(AccessToken, Opts) ->
    Opts1 = set_defaults([{environment, <<"default">>}
                         ,{platform, <<"beam">>}
                         ,{batch_max, config(batch_max)}
                         ,{rpm_max, 0}
                         ,{endpoint, config(endpoint)}
                         ,{host, hostname()}
                         ,{report_handlers, erollbar_handlers:default_handlers()}
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
    case lists:member(Key, [environment, batch_max, rpm_max, host, endpoint, root, branch,
                            platform, time_max, http_timeout, report_handlers]) of
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

config(Key) ->
    case application:get_env(erollbar, Key) of
        {ok, Val} ->
            Val;
        _ ->
            throw({missing_config, Key})
    end.
