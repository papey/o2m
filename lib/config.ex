defmodule O2M.Config do
  @moduledoc """
  A module to handle o2m config from env using ETS
  """

  # base config
  @base [
    {:pass, :nickname, "O2M_NICKNAME", "Orgie 2 Metal"},
    {:pass, :prefix, "O2M_PREFIX", "!"},
    {:pass, :feed_urls, "O2M_FEED_URLS", ""},
    {:pass, :tmpl_dets, "O2M_TMPL_DETS", "/srv/o2m/dets/templates.dets"},
    {:convert, :jobs_timer, "O2M_JOBS_TIMER", "500"},
    {:convert, :guild, "O2M_GUILD_ID", :no_default},
    {:convert, :chan, "O2M_CHAN_ID", :no_default}
  ]

  # bt config
  @bt [
    {:convert, :bt_chan, "O2M_BT_CHAN_ID", :no_default},
    {:convert, :bt_admin, "O2M_BT_ADMIN", :no_default},
    {:convert, :bt_vocal, "O2M_BT_VOCAL_ID", :no_default},
    {:pass, :bt_cache, "O2M_BT_CACHE", "/tmp/o2m/cache"},
    {:pass, :bt_lboard, "O2M_BT_LBOARD_DETS", "/srv/o2m/dets/leaderboard.dets"},
    {:pass, :bt_events_tz, "O2M_BT_EVENTS_TZ", "Europe/Paris"}
  ]

  @bt_mandatory_keys [
    "O2M_BT_ADMIN",
    "O2M_BT_CHAN_ID",
    "O2M_BT_VOCAL_ID"
  ]

  def init!() do
    :ets.new(:config_lookup, [:set, :protected, :named_table])

    insert!(@base)

    if blindtest?() do
      insert!(@bt)
      insert!({:bt, true})
    end

    :config_lookup
  end

  def get(key) do
    [{_, v}] = :ets.lookup(:config_lookup, key)
    v
  end

  defp get_env!({convert, key, env_key, :no_default}) do
    case System.get_env(env_key) do
      nil -> raise "No key found for mandatory env value #{key}"
      value -> {convert, key, value}
    end
  end

  defp get_env!({convert, key, env_key, default}),
    do: {convert, key, System.get_env(env_key, default)}

  defp to_int!({:convert, key, value}) do
    case Integer.parse(value) do
      {parsed, ""} -> {key, parsed}
      :error -> raise "Error when trying to parse integer value #{value}"
    end
  end

  defp to_int!({:pass, key, value}), do: {key, value}

  defp insert!(entries) when is_list(entries) do
    # Env with default
    for entry <- entries do
      entry
      |> get_env!()
      |> to_int!()
      |> insert!()
    end
  end

  defp insert!({key, value}), do: :ets.insert_new(:config_lookup, {key, value})

  defp blindtest?() do
    configured = Enum.take_while(@bt_mandatory_keys, &(System.get_env(&1) != nil))

    length(@bt_mandatory_keys) == length(configured)
  end

  def purge! do
    :ets.delete(:config_lookup)
  end
end
