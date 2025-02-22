#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.Housekeeping.RPC.Handler do
  @behaviour Astarte.RPC.Handler

  alias Astarte.Housekeeping.Engine

  alias Astarte.RPC.Protocol.Housekeeping.{
    Call,
    CreateRealm,
    DoesRealmExist,
    DoesRealmExistReply,
    GenericErrorReply,
    GenericOkReply,
    GetHealth,
    GetHealthReply,
    GetRealm,
    GetRealmReply,
    GetRealmsList,
    GetRealmsListReply,
    Reply
  }

  require Logger

  def handle_rpc(payload) do
    with {:ok, call_tuple} <- extract_call_tuple(Call.decode(payload)) do
      call_rpc(call_tuple)
    end
  end

  defp extract_call_tuple(%Call{call: nil}) do
    Logger.warn("Received empty call")
    {:error, :empty_call}
  end

  defp extract_call_tuple(%Call{call: call_tuple}) do
    {:ok, call_tuple}
  end

  defp call_rpc({:create_realm, %CreateRealm{realm: nil}}) do
    Logger.warn("CreateRealm with realm == nil")
    generic_error(:empty_name, "empty realm name")
  end

  defp call_rpc({:create_realm, %CreateRealm{jwt_public_key_pem: nil}}) do
    Logger.warn("CreateRealm with jwt_public_key_pem == nil")
    generic_error(:empty_public_key, "empty jwt public key pem")
  end

  defp call_rpc(
         {:create_realm,
          %CreateRealm{
            realm: realm,
            jwt_public_key_pem: pub_key,
            replication_class: :NETWORK_TOPOLOGY_STRATEGY,
            datacenter_replication_factors: datacenter_replication_factors,
            async_operation: async
          }}
       ) do
    if Astarte.Housekeeping.Engine.realm_exists?(realm) do
      generic_error(:existing_realm, "realm already exists")
    else
      datacenter_replication_factors_map = Enum.into(datacenter_replication_factors, %{})

      case Engine.create_realm(realm, pub_key, datacenter_replication_factors_map, async: async) do
        {:error, {reason, details}} -> generic_error(reason, details)
        {:error, reason} -> generic_error(reason)
        :ok -> generic_ok(async)
      end
    end
  end

  defp call_rpc(
         {:create_realm,
          %CreateRealm{
            realm: realm,
            jwt_public_key_pem: pub_key,
            replication_factor: replication_factor,
            async_operation: async
          }}
       ) do
    if Astarte.Housekeeping.Engine.realm_exists?(realm) do
      generic_error(:existing_realm, "realm already exists")
    else
      case Engine.create_realm(realm, pub_key, replication_factor, async: async) do
        {:error, {reason, details}} -> generic_error(reason, details)
        {:error, reason} -> generic_error(reason)
        :ok -> generic_ok(async)
      end
    end
  end

  defp call_rpc({:does_realm_exist, %DoesRealmExist{realm: realm}}) do
    exists = Astarte.Housekeeping.Engine.realm_exists?(realm)

    %DoesRealmExistReply{exists: exists}
    |> encode_reply(:does_realm_exist_reply)
    |> ok_wrap
  end

  defp call_rpc({:get_health, %GetHealth{}}) do
    {:ok, %{status: status}} = Engine.get_health()

    status_enum =
      case status do
        :ready -> :READY
        :degraded -> :DEGRADED
        :bad -> :BAD
        :error -> :ERROR
      end

    %GetHealthReply{status: status_enum}
    |> encode_reply(:get_health_reply)
    |> ok_wrap
  end

  defp call_rpc({:get_realms_list, %GetRealmsList{}}) do
    list = Astarte.Housekeeping.Engine.realms_list()

    %GetRealmsListReply{realms_names: list}
    |> encode_reply(:get_realms_list_reply)
    |> ok_wrap
  end

  defp call_rpc({:get_realm, %GetRealm{realm_name: realm_name}}) do
    case Astarte.Housekeeping.Engine.get_realm(realm_name) do
      %{
        realm_name: realm_name_reply,
        jwt_public_key_pem: public_key,
        replication_class: "SimpleStrategy",
        replication_factor: replication_factor
      } ->
        %GetRealmReply{
          realm_name: realm_name_reply,
          jwt_public_key_pem: public_key,
          replication_class: :SIMPLE_STRATEGY,
          replication_factor: replication_factor
        }
        |> encode_reply(:get_realm_reply)
        |> ok_wrap

      %{
        realm_name: realm_name_reply,
        jwt_public_key_pem: public_key,
        replication_class: "NetworkTopologyStrategy",
        datacenter_replication_factors: datacenter_replication_factors
      } ->
        datacenter_replication_factors_list = Enum.into(datacenter_replication_factors, [])

        %GetRealmReply{
          realm_name: realm_name_reply,
          jwt_public_key_pem: public_key,
          replication_class: :NETWORK_TOPOLOGY_STRATEGY,
          datacenter_replication_factors: datacenter_replication_factors_list
        }
        |> encode_reply(:get_realm_reply)
        |> ok_wrap

      {:error, reason} ->
        generic_error(reason)
    end
  end

  defp generic_error(
         error_name,
         user_readable_message \\ nil,
         user_readable_error_name \\ nil,
         error_data \\ nil
       ) do
    %GenericErrorReply{
      error_name: to_string(error_name),
      user_readable_message: user_readable_message,
      user_readable_error_name: user_readable_error_name,
      error_data: error_data
    }
    |> encode_reply(:generic_error_reply)
    |> ok_wrap
  end

  defp generic_ok(async) do
    %GenericOkReply{async_operation: async}
    |> encode_reply(:generic_ok_reply)
    |> ok_wrap
  end

  defp encode_reply(%GenericErrorReply{} = reply, _reply_type) do
    %Reply{reply: {:generic_error_reply, reply}, error: true}
    |> Reply.encode()
  end

  defp encode_reply(reply, reply_type) do
    %Reply{reply: {reply_type, reply}}
    |> Reply.encode()
  end

  defp ok_wrap(result) do
    {:ok, result}
  end
end
