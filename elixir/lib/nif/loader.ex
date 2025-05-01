defmodule Tailscale.NIF do
  @moduledoc false

  @on_load :load_nifs

  def load_nifs do
    priv_dir = :code.priv_dir(:tailscale)
    nif_path = Path.join(priv_dir, "tailscale_nif")
    
    case :erlang.load_nif(to_charlist(nif_path), 0) do
      :ok -> :ok
      {:error, {:load_failed, reason}} ->
        raise "Failed to load NIF module: #{inspect(reason)}"
      {:error, reason} ->
        raise "Failed to load NIF module: #{inspect(reason)}"
    end
  end

  # Core Tailscale functions
  def tailscale_new, do: :erlang.nif_error(:nif_not_loaded)
  def tailscale_start(_sd), do: :erlang.nif_error(:nif_not_loaded)
  def tailscale_up(_sd), do: :erlang.nif_error(:nif_not_loaded)
  def tailscale_close(_sd), do: :erlang.nif_error(:nif_not_loaded)
  def tailscale_errmsg(_sd, _buflen), do: :erlang.nif_error(:nif_not_loaded)

  # Configuration functions
  def tailscale_set_dir(_sd, _dir), do: :erlang.nif_error(:nif_not_loaded)
  def tailscale_set_hostname(_sd, _hostname), do: :erlang.nif_error(:nif_not_loaded)
  def tailscale_set_authkey(_sd, _authkey), do: :erlang.nif_error(:nif_not_loaded)
  def tailscale_set_control_url(_sd, _control_url), do: :erlang.nif_error(:nif_not_loaded)
  def tailscale_set_ephemeral(_sd, _ephemeral), do: :erlang.nif_error(:nif_not_loaded)
  def tailscale_set_logfd(_sd, _fd), do: :erlang.nif_error(:nif_not_loaded)

  # Networking functions
  def tailscale_dial(_sd, _network, _addr), do: :erlang.nif_error(:nif_not_loaded)
  def tailscale_listen(_sd, _network, _addr), do: :erlang.nif_error(:nif_not_loaded)
  def tailscale_accept(_listener), do: :erlang.nif_error(:nif_not_loaded)
  def tailscale_getips(_sd, _buflen), do: :erlang.nif_error(:nif_not_loaded)
  def tailscale_getremoteaddr(_listener, _conn, _buflen), do: :erlang.nif_error(:nif_not_loaded)

  # LocalAPI and funnel functions
  def tailscale_loopback(_sd, _addrlen), do: :erlang.nif_error(:nif_not_loaded)
  def tailscale_enable_funnel(_sd, _localhostPort), do: :erlang.nif_error(:nif_not_loaded)
end