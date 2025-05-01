defmodule Tailscale do
  @moduledoc """
  Elixir bindings for Tailscale, allowing you to embed Tailscale networking directly
  in your Elixir applications.
  """

  alias Tailscale.Error
  alias Tailscale.Listener
  alias Tailscale.LocalAPI
  alias Tailscale.NIF

  defstruct [:reference]

  @type t :: %__MODULE__{
    reference: reference()
  }

  @doc """
  Create a new Tailscale instance.

  ## Examples

      iex> {:ok, ts} = Tailscale.new()
      {:ok, %Tailscale{...}}

  """
  @spec new() :: {:ok, t()} | {:error, Error.t()}
  def new do
    case NIF.tailscale_new() do
      {:ok, reference} ->
        {:ok, %__MODULE__{reference: reference}}
      {:error, reason} ->
        {:error, Error.new("Failed to create Tailscale instance", reason)}
    end
  end

  @doc """
  Start the Tailscale service asynchronously.

  ## Examples

      iex> {:ok, ts} = Tailscale.new()
      iex> Tailscale.start(ts)
      :ok

  """
  @spec start(t()) :: :ok | {:error, Error.t()}
  def start(%__MODULE__{reference: reference}) do
    case NIF.tailscale_start(reference) do
      :ok -> :ok
      {:error, reason} ->
        {:error, Error.new("Failed to start Tailscale", reason)}
    end
  end

  @doc """
  Connect the Tailscale service to the tailnet and wait for it to be usable.
  This is a blocking operation.

  ## Examples

      iex> {:ok, ts} = Tailscale.new()
      iex> Tailscale.up(ts)
      :ok

  """
  @spec up(t()) :: :ok | {:error, Error.t()}
  def up(%__MODULE__{reference: reference}) do
    case NIF.tailscale_up(reference) do
      :ok -> :ok
      {:error, reason} when is_atom(reason) ->
        {:error, Error.new("Failed to bring Tailscale up", reason)}
      {:error, msg} when is_binary(msg) ->
        {:error, Error.new(msg)}
    end
  end

  @doc """
  Close the Tailscale service.

  ## Examples

      iex> {:ok, ts} = Tailscale.new()
      iex> Tailscale.close(ts)
      :ok

  """
  @spec close(t()) :: :ok | {:error, Error.t()}
  def close(%__MODULE__{reference: reference}) do
    case NIF.tailscale_close(reference) do
      :ok -> :ok
      {:error, reason} ->
        {:error, Error.new("Failed to close Tailscale", reason)}
    end
  end

  @doc """
  Set the directory where Tailscale will store its state files.

  ## Examples

      iex> {:ok, ts} = Tailscale.new()
      iex> Tailscale.set_dir(ts, "/tmp/tailscale")
      :ok

  """
  @spec set_dir(t(), String.t()) :: :ok | {:error, Error.t()}
  def set_dir(%__MODULE__{reference: reference}, dir) do
    case NIF.tailscale_set_dir(reference, dir) do
      :ok -> :ok
      {:error, reason} ->
        {:error, Error.new("Failed to set Tailscale directory", reason)}
    end
  end

  @doc """
  Set the hostname for the Tailscale node.

  ## Examples

      iex> {:ok, ts} = Tailscale.new()
      iex> Tailscale.set_hostname(ts, "my-elixir-app")
      :ok

  """
  @spec set_hostname(t(), String.t()) :: :ok | {:error, Error.t()}
  def set_hostname(%__MODULE__{reference: reference}, hostname) do
    case NIF.tailscale_set_hostname(reference, hostname) do
      :ok -> :ok
      {:error, reason} ->
        {:error, Error.new("Failed to set Tailscale hostname", reason)}
    end
  end

  @doc """
  Set the authentication key for the Tailscale node.

  ## Examples

      iex> {:ok, ts} = Tailscale.new()
      iex> Tailscale.set_auth_key(ts, "tskey-abc123...")
      :ok

  """
  @spec set_auth_key(t(), String.t()) :: :ok | {:error, Error.t()}
  def set_auth_key(%__MODULE__{reference: reference}, auth_key) do
    case NIF.tailscale_set_authkey(reference, auth_key) do
      :ok -> :ok
      {:error, reason} ->
        {:error, Error.new("Failed to set Tailscale auth key", reason)}
    end
  end

  @doc """
  Set the control URL for the Tailscale node.

  ## Examples

      iex> {:ok, ts} = Tailscale.new()
      iex> Tailscale.set_control_url(ts, "https://controlplane.tailscale.com")
      :ok

  """
  @spec set_control_url(t(), String.t()) :: :ok | {:error, Error.t()}
  def set_control_url(%__MODULE__{reference: reference}, control_url) do
    case NIF.tailscale_set_control_url(reference, control_url) do
      :ok -> :ok
      {:error, reason} ->
        {:error, Error.new("Failed to set Tailscale control URL", reason)}
    end
  end

  @doc """
  Set whether the Tailscale node is ephemeral.

  ## Examples

      iex> {:ok, ts} = Tailscale.new()
      iex> Tailscale.set_ephemeral(ts, true)
      :ok

  """
  @spec set_ephemeral(t(), boolean()) :: :ok | {:error, Error.t()}
  def set_ephemeral(%__MODULE__{reference: reference}, ephemeral) do
    ephemeral_int = if ephemeral, do: 1, else: 0
    
    case NIF.tailscale_set_ephemeral(reference, ephemeral_int) do
      :ok -> :ok
      {:error, reason} ->
        {:error, Error.new("Failed to set Tailscale ephemeral mode", reason)}
    end
  end

  @doc """
  Set the log file descriptor for the Tailscale node.

  ## Examples

      iex> {:ok, ts} = Tailscale.new()
      iex> {:ok, fd} = File.open("/tmp/tailscale.log", [:write])
      iex> Tailscale.set_log_fd(ts, fd)
      :ok

  """
  @spec set_log_fd(t(), integer() | File.io_device()) :: :ok | {:error, Error.t()}
  def set_log_fd(%__MODULE__{reference: reference}, fd) when is_integer(fd) do
    case NIF.tailscale_set_logfd(reference, fd) do
      :ok -> :ok
      {:error, reason} ->
        {:error, Error.new("Failed to set Tailscale log FD", reason)}
    end
  end

  def set_log_fd(%__MODULE__{} = ts, io_device) do
    fd = :erlang.map_get(:fd, :erlang.port_info(io_device, :fd))
    set_log_fd(ts, fd)
  end

  @doc """
  Dial a connection to a Tailscale node.

  ## Examples

      iex> {:ok, ts} = Tailscale.new()
      iex> {:ok, socket} = Tailscale.dial(ts, "tcp", "100.100.100.100:80")
      {:ok, socket}

  """
  @spec dial(t(), String.t(), String.t()) :: {:ok, :inet.socket()} | {:error, Error.t()}
  def dial(%__MODULE__{reference: reference}, network, addr) do
    case NIF.tailscale_dial(reference, network, addr) do
      {:ok, fd} ->
        # Convert the file descriptor into a socket that can be used with gen_tcp
        case :erlang.open_port({:fd, fd, fd}, [:binary]) do
          port when is_port(port) ->
            {:ok, port}
          _ ->
            {:error, Error.new("Failed to open port for socket")}
        end
      {:error, reason} ->
        {:error, Error.new("Failed to dial", reason)}
    end
  end

  @doc """
  Create a listener on the Tailscale network.

  ## Examples

      iex> {:ok, ts} = Tailscale.new()
      iex> {:ok, listener} = Tailscale.listen(ts, "tcp", ":8080")
      {:ok, %Tailscale.Listener{...}}

  """
  @spec listen(t(), String.t(), String.t()) :: {:ok, Listener.t()} | {:error, Error.t()}
  def listen(%__MODULE__{reference: reference}, network, addr) do
    case NIF.tailscale_listen(reference, network, addr) do
      {:ok, listener_ref} ->
        {:ok, %Listener{reference: listener_ref, server: self()}}
      {:error, reason} ->
        {:error, Error.new("Failed to create listener", reason)}
    end
  end

  @doc """
  Get the IP addresses of the Tailscale node.

  ## Examples

      iex> {:ok, ts} = Tailscale.new()
      iex> {:ok, ips} = Tailscale.get_ips(ts)
      {:ok, "100.100.100.100,fd7a:115c:a1e0:ab12:4843:cd96:6243:10a3"}

  """
  @spec get_ips(t()) :: {:ok, String.t()} | {:error, Error.t()}
  def get_ips(%__MODULE__{reference: reference}) do
    case NIF.tailscale_getips(reference, 1024) do
      {:ok, ips} -> {:ok, ips}
      {:error, reason} ->
        {:error, Error.new("Failed to get Tailscale IPs", reason)}
    end
  end

  @doc """
  Start a loopback address server for the Tailscale Local API.

  ## Examples

      iex> {:ok, ts} = Tailscale.new()
      iex> {:ok, {addr, proxy_cred, local_api_cred}} = Tailscale.loopback(ts)
      {:ok, {"127.0.0.1:8000", "abc123", "def456"}}

  """
  @spec loopback(t()) :: {:ok, {String.t(), String.t(), String.t()}} | {:error, Error.t()}
  def loopback(%__MODULE__{reference: reference}) do
    case NIF.tailscale_loopback(reference, 1024) do
      {:ok, {addr, proxy_cred, local_api_cred}} ->
        {:ok, {addr, proxy_cred, local_api_cred}}
      {:error, reason} ->
        {:error, Error.new("Failed to start loopback server", reason)}
    end
  end

  @doc """
  Create a LocalAPI client for the Tailscale node.

  ## Examples

      iex> {:ok, ts} = Tailscale.new()
      iex> {:ok, client} = Tailscale.local_api_client(ts)
      {:ok, %Tailscale.LocalAPI.Client{...}}

  """
  @spec local_api_client(t()) :: {:ok, LocalAPI.Client.t()} | {:error, Error.t()}
  def local_api_client(%__MODULE__{} = ts) do
    case loopback(ts) do
      {:ok, {addr, _proxy_cred, local_api_cred}} ->
        {:ok, LocalAPI.Client.new(addr, local_api_cred)}
      error ->
        error
    end
  end

  @doc """
  Enable Tailscale Funnel to forward HTTPS traffic to a local HTTP server.

  ## Examples

      iex> {:ok, ts} = Tailscale.new()
      iex> Tailscale.enable_funnel(ts, 8080)
      :ok

  """
  @spec enable_funnel(t(), integer()) :: :ok | {:error, Error.t()}
  def enable_funnel(%__MODULE__{reference: reference}, port) do
    case NIF.tailscale_enable_funnel(reference, port) do
      :ok -> :ok
      {:error, reason} ->
        {:error, Error.new("Failed to enable Tailscale funnel", reason)}
    end
  end

  @doc """
  Get the error message from the last Tailscale operation.

  ## Examples

      iex> {:ok, ts} = Tailscale.new()
      iex> Tailscale.error_message(ts)
      {:ok, ""}

  """
  @spec error_message(t()) :: {:ok, String.t()} | {:error, Error.t()}
  def error_message(%__MODULE__{reference: reference}) do
    case NIF.tailscale_errmsg(reference, 1024) do
      {:ok, msg} -> {:ok, msg}
      {:error, reason} ->
        {:error, Error.new("Failed to get error message", reason)}
    end
  end
end