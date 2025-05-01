// Copyright (c) Tailscale Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

#include <erl_nif.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "tailscale.h"

#define MAX_ERRMSG_LEN 1024
#define MAX_ADDR_LEN 1024

// Resource types for managing tailscale handles
static ErlNifResourceType *tailscale_resource_type = NULL;
static ErlNifResourceType *tailscale_listener_resource_type = NULL;

// Resource wrapper for tailscale handle
typedef struct {
    tailscale sd;
} tailscale_handle;

// Resource wrapper for tailscale_listener handle
typedef struct {
    tailscale_listener listener;
} tailscale_listener_handle;

// Forward declarations for resource destructors
static void tailscale_resource_dtor(ErlNifEnv *env, void *obj);
static void tailscale_listener_resource_dtor(ErlNifEnv *env, void *obj);

// Helpers
static ERL_NIF_TERM make_error(ErlNifEnv *env, const char *error_msg);
static ERL_NIF_TERM make_ok(ErlNifEnv *env, ERL_NIF_TERM value);
static ERL_NIF_TERM make_ok_tuple(ErlNifEnv *env);
static ERL_NIF_TERM make_error_tuple(ErlNifEnv *env, const char *reason);
static ERL_NIF_TERM get_error_message(ErlNifEnv *env, tailscale sd);

// Core Tailscale NIF functions
static ERL_NIF_TERM tailscale_new_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    tailscale_handle *handle = enif_alloc_resource(tailscale_resource_type, sizeof(tailscale_handle));
    if (!handle) {
        return make_error_tuple(env, "out_of_memory");
    }

    handle->sd = tailscale_new();
    if (handle->sd < 0) {
        enif_release_resource(handle);
        return make_error_tuple(env, "failed_to_create_tailscale");
    }

    ERL_NIF_TERM result = enif_make_resource(env, handle);
    enif_release_resource(handle); // The resource is now only owned by Erlang

    return make_ok(env, result);
}

static ERL_NIF_TERM tailscale_start_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    tailscale_handle *handle;
    if (!enif_get_resource(env, argv[0], tailscale_resource_type, (void **)&handle)) {
        return make_error_tuple(env, "invalid_tailscale_handle");
    }

    int ret = tailscale_start(handle->sd);
    if (ret != 0) {
        return make_error_tuple(env, "failed_to_start_tailscale");
    }

    return make_ok_tuple(env);
}

static ERL_NIF_TERM tailscale_up_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    tailscale_handle *handle;
    if (!enif_get_resource(env, argv[0], tailscale_resource_type, (void **)&handle)) {
        return make_error_tuple(env, "invalid_tailscale_handle");
    }

    int ret = tailscale_up(handle->sd);
    if (ret != 0) {
        ERL_NIF_TERM err_msg = get_error_message(env, handle->sd);
        return enif_make_tuple2(env, enif_make_atom(env, "error"), err_msg);
    }

    return make_ok_tuple(env);
}

static ERL_NIF_TERM tailscale_close_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    tailscale_handle *handle;
    if (!enif_get_resource(env, argv[0], tailscale_resource_type, (void **)&handle)) {
        return make_error_tuple(env, "invalid_tailscale_handle");
    }

    int ret = tailscale_close(handle->sd);
    if (ret != 0) {
        return make_error_tuple(env, "failed_to_close_tailscale");
    }

    handle->sd = -1; // Mark as closed
    return make_ok_tuple(env);
}

static ERL_NIF_TERM tailscale_errmsg_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    tailscale_handle *handle;
    unsigned long buf_size;

    if (!enif_get_resource(env, argv[0], tailscale_resource_type, (void **)&handle)) {
        return make_error_tuple(env, "invalid_tailscale_handle");
    }

    if (!enif_get_ulong(env, argv[1], &buf_size)) {
        return make_error_tuple(env, "invalid_buffer_size");
    }

    char *buf = (char *)enif_alloc(buf_size);
    if (!buf) {
        return make_error_tuple(env, "out_of_memory");
    }

    int ret = tailscale_errmsg(handle->sd, buf, buf_size);
    if (ret != 0) {
        enif_free(buf);
        return make_error_tuple(env, "failed_to_get_error_message");
    }

    ERL_NIF_TERM result = enif_make_string(env, buf, ERL_NIF_LATIN1);
    enif_free(buf);

    return make_ok(env, result);
}

// Configuration functions
static ERL_NIF_TERM tailscale_set_dir_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    tailscale_handle *handle;
    char dir[256];

    if (!enif_get_resource(env, argv[0], tailscale_resource_type, (void **)&handle)) {
        return make_error_tuple(env, "invalid_tailscale_handle");
    }

    if (!enif_get_string(env, argv[1], dir, sizeof(dir), ERL_NIF_LATIN1)) {
        return make_error_tuple(env, "invalid_directory_string");
    }

    int ret = tailscale_set_dir(handle->sd, dir);
    if (ret != 0) {
        return make_error_tuple(env, "failed_to_set_directory");
    }

    return make_ok_tuple(env);
}

static ERL_NIF_TERM tailscale_set_hostname_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    tailscale_handle *handle;
    char hostname[256];

    if (!enif_get_resource(env, argv[0], tailscale_resource_type, (void **)&handle)) {
        return make_error_tuple(env, "invalid_tailscale_handle");
    }

    if (!enif_get_string(env, argv[1], hostname, sizeof(hostname), ERL_NIF_LATIN1)) {
        return make_error_tuple(env, "invalid_hostname_string");
    }

    int ret = tailscale_set_hostname(handle->sd, hostname);
    if (ret != 0) {
        return make_error_tuple(env, "failed_to_set_hostname");
    }

    return make_ok_tuple(env);
}

static ERL_NIF_TERM tailscale_set_authkey_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    tailscale_handle *handle;
    char authkey[256];

    if (!enif_get_resource(env, argv[0], tailscale_resource_type, (void **)&handle)) {
        return make_error_tuple(env, "invalid_tailscale_handle");
    }

    if (!enif_get_string(env, argv[1], authkey, sizeof(authkey), ERL_NIF_LATIN1)) {
        return make_error_tuple(env, "invalid_authkey_string");
    }

    int ret = tailscale_set_authkey(handle->sd, authkey);
    if (ret != 0) {
        return make_error_tuple(env, "failed_to_set_authkey");
    }

    return make_ok_tuple(env);
}

static ERL_NIF_TERM tailscale_set_control_url_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    tailscale_handle *handle;
    char control_url[256];

    if (!enif_get_resource(env, argv[0], tailscale_resource_type, (void **)&handle)) {
        return make_error_tuple(env, "invalid_tailscale_handle");
    }

    if (!enif_get_string(env, argv[1], control_url, sizeof(control_url), ERL_NIF_LATIN1)) {
        return make_error_tuple(env, "invalid_control_url_string");
    }

    int ret = tailscale_set_control_url(handle->sd, control_url);
    if (ret != 0) {
        return make_error_tuple(env, "failed_to_set_control_url");
    }

    return make_ok_tuple(env);
}

static ERL_NIF_TERM tailscale_set_ephemeral_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    tailscale_handle *handle;
    int ephemeral;

    if (!enif_get_resource(env, argv[0], tailscale_resource_type, (void **)&handle)) {
        return make_error_tuple(env, "invalid_tailscale_handle");
    }

    if (!enif_get_int(env, argv[1], &ephemeral)) {
        return make_error_tuple(env, "invalid_ephemeral_value");
    }

    int ret = tailscale_set_ephemeral(handle->sd, ephemeral);
    if (ret != 0) {
        return make_error_tuple(env, "failed_to_set_ephemeral");
    }

    return make_ok_tuple(env);
}

static ERL_NIF_TERM tailscale_set_logfd_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    tailscale_handle *handle;
    int fd;

    if (!enif_get_resource(env, argv[0], tailscale_resource_type, (void **)&handle)) {
        return make_error_tuple(env, "invalid_tailscale_handle");
    }

    if (!enif_get_int(env, argv[1], &fd)) {
        return make_error_tuple(env, "invalid_fd_value");
    }

    int ret = tailscale_set_logfd(handle->sd, fd);
    if (ret != 0) {
        return make_error_tuple(env, "failed_to_set_logfd");
    }

    return make_ok_tuple(env);
}

// Networking functions
static ERL_NIF_TERM tailscale_dial_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    tailscale_handle *handle;
    char network[32];
    char addr[256];
    tailscale_conn conn_out;

    if (!enif_get_resource(env, argv[0], tailscale_resource_type, (void **)&handle)) {
        return make_error_tuple(env, "invalid_tailscale_handle");
    }

    if (!enif_get_string(env, argv[1], network, sizeof(network), ERL_NIF_LATIN1)) {
        return make_error_tuple(env, "invalid_network_string");
    }

    if (!enif_get_string(env, argv[2], addr, sizeof(addr), ERL_NIF_LATIN1)) {
        return make_error_tuple(env, "invalid_addr_string");
    }

    int ret = tailscale_dial(handle->sd, network, addr, &conn_out);
    if (ret != 0) {
        return make_error_tuple(env, "failed_to_dial");
    }

    return make_ok(env, enif_make_int(env, conn_out));
}

static ERL_NIF_TERM tailscale_listen_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    tailscale_handle *handle;
    char network[32];
    char addr[256];
    
    if (!enif_get_resource(env, argv[0], tailscale_resource_type, (void **)&handle)) {
        return make_error_tuple(env, "invalid_tailscale_handle");
    }

    if (!enif_get_string(env, argv[1], network, sizeof(network), ERL_NIF_LATIN1)) {
        return make_error_tuple(env, "invalid_network_string");
    }

    if (!enif_get_string(env, argv[2], addr, sizeof(addr), ERL_NIF_LATIN1)) {
        return make_error_tuple(env, "invalid_addr_string");
    }

    tailscale_listener_handle *listener_handle = enif_alloc_resource(
        tailscale_listener_resource_type,
        sizeof(tailscale_listener_handle)
    );
    
    if (!listener_handle) {
        return make_error_tuple(env, "out_of_memory");
    }

    int ret = tailscale_listen(handle->sd, network, addr, &listener_handle->listener);
    if (ret != 0) {
        enif_release_resource(listener_handle);
        return make_error_tuple(env, "failed_to_listen");
    }

    ERL_NIF_TERM result = enif_make_resource(env, listener_handle);
    enif_release_resource(listener_handle); // The resource is now only owned by Erlang

    return make_ok(env, result);
}

static ERL_NIF_TERM tailscale_accept_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    tailscale_listener_handle *listener_handle;
    tailscale_conn conn_out;

    if (!enif_get_resource(env, argv[0], tailscale_listener_resource_type, (void **)&listener_handle)) {
        return make_error_tuple(env, "invalid_listener_handle");
    }

    int ret = tailscale_accept(listener_handle->listener, &conn_out);
    if (ret != 0) {
        return make_error_tuple(env, "failed_to_accept");
    }

    return make_ok(env, enif_make_int(env, conn_out));
}

static ERL_NIF_TERM tailscale_getips_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    tailscale_handle *handle;
    unsigned long buf_size;

    if (!enif_get_resource(env, argv[0], tailscale_resource_type, (void **)&handle)) {
        return make_error_tuple(env, "invalid_tailscale_handle");
    }

    if (!enif_get_ulong(env, argv[1], &buf_size)) {
        return make_error_tuple(env, "invalid_buffer_size");
    }

    char *buf = (char *)enif_alloc(buf_size);
    if (!buf) {
        return make_error_tuple(env, "out_of_memory");
    }

    int ret = tailscale_getips(handle->sd, buf, buf_size);
    if (ret != 0) {
        enif_free(buf);
        return make_error_tuple(env, "failed_to_get_ips");
    }

    ERL_NIF_TERM result = enif_make_string(env, buf, ERL_NIF_LATIN1);
    enif_free(buf);

    return make_ok(env, result);
}

static ERL_NIF_TERM tailscale_getremoteaddr_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    tailscale_listener_handle *listener_handle;
    tailscale_conn conn;
    unsigned long buf_size;

    if (!enif_get_resource(env, argv[0], tailscale_listener_resource_type, (void **)&listener_handle)) {
        return make_error_tuple(env, "invalid_listener_handle");
    }

    if (!enif_get_int(env, argv[1], &conn)) {
        return make_error_tuple(env, "invalid_connection_handle");
    }

    if (!enif_get_ulong(env, argv[2], &buf_size)) {
        return make_error_tuple(env, "invalid_buffer_size");
    }

    char *buf = (char *)enif_alloc(buf_size);
    if (!buf) {
        return make_error_tuple(env, "out_of_memory");
    }

    int ret = tailscale_getremoteaddr(listener_handle->listener, conn, buf, buf_size);
    if (ret != 0) {
        enif_free(buf);
        return make_error_tuple(env, "failed_to_get_remote_addr");
    }

    ERL_NIF_TERM result = enif_make_string(env, buf, ERL_NIF_LATIN1);
    enif_free(buf);

    return make_ok(env, result);
}

// LocalAPI and funnel functions
static ERL_NIF_TERM tailscale_loopback_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    tailscale_handle *handle;
    unsigned long addr_len;

    if (!enif_get_resource(env, argv[0], tailscale_resource_type, (void **)&handle)) {
        return make_error_tuple(env, "invalid_tailscale_handle");
    }

    if (!enif_get_ulong(env, argv[1], &addr_len)) {
        return make_error_tuple(env, "invalid_address_length");
    }

    // Ensure addr_len is reasonable
    if (addr_len > MAX_ADDR_LEN) {
        return make_error_tuple(env, "address_length_too_large");
    }

    char *addr_out = (char *)enif_alloc(addr_len);
    char proxy_cred_out[33];
    char local_api_cred_out[33];

    if (!addr_out) {
        return make_error_tuple(env, "out_of_memory");
    }

    int ret = tailscale_loopback(handle->sd, addr_out, addr_len, proxy_cred_out, local_api_cred_out);
    if (ret != 0) {
        enif_free(addr_out);
        return make_error_tuple(env, "failed_to_start_loopback");
    }

    ERL_NIF_TERM addr_term = enif_make_string(env, addr_out, ERL_NIF_LATIN1);
    ERL_NIF_TERM proxy_cred_term = enif_make_string(env, proxy_cred_out, ERL_NIF_LATIN1);
    ERL_NIF_TERM local_api_cred_term = enif_make_string(env, local_api_cred_out, ERL_NIF_LATIN1);

    enif_free(addr_out);

    ERL_NIF_TERM result = enif_make_tuple3(env, addr_term, proxy_cred_term, local_api_cred_term);
    return make_ok(env, result);
}

static ERL_NIF_TERM tailscale_enable_funnel_nif(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
    tailscale_handle *handle;
    int localhost_port;

    if (!enif_get_resource(env, argv[0], tailscale_resource_type, (void **)&handle)) {
        return make_error_tuple(env, "invalid_tailscale_handle");
    }

    if (!enif_get_int(env, argv[1], &localhost_port)) {
        return make_error_tuple(env, "invalid_port_number");
    }

    int ret = tailscale_enable_funnel_to_localhost_plaintext_http1(handle->sd, localhost_port);
    if (ret != 0) {
        return make_error_tuple(env, "failed_to_enable_funnel");
    }

    return make_ok_tuple(env);
}

// Helpers
static ERL_NIF_TERM make_error(ErlNifEnv *env, const char *error_msg) {
    return enif_make_tuple2(env, 
                           enif_make_atom(env, "error"),
                           enif_make_atom(env, error_msg));
}

static ERL_NIF_TERM make_ok(ErlNifEnv *env, ERL_NIF_TERM value) {
    return enif_make_tuple2(env, enif_make_atom(env, "ok"), value);
}

static ERL_NIF_TERM make_ok_tuple(ErlNifEnv *env) {
    return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM make_error_tuple(ErlNifEnv *env, const char *reason) {
    return enif_make_tuple2(env, 
                           enif_make_atom(env, "error"),
                           enif_make_atom(env, reason));
}

static ERL_NIF_TERM get_error_message(ErlNifEnv *env, tailscale sd) {
    char err_buf[MAX_ERRMSG_LEN];
    int ret = tailscale_errmsg(sd, err_buf, sizeof(err_buf));
    
    if (ret != 0) {
        return enif_make_atom(env, "unknown_error");
    }
    
    return enif_make_string(env, err_buf, ERL_NIF_LATIN1);
}

// Resource destructors
static void tailscale_resource_dtor(ErlNifEnv *env, void *obj) {
    tailscale_handle *handle = (tailscale_handle *)obj;
    if (handle->sd >= 0) {
        tailscale_close(handle->sd);
        handle->sd = -1;
    }
}

static void tailscale_listener_resource_dtor(ErlNifEnv *env, void *obj) {
    tailscale_listener_handle *listener_handle = (tailscale_listener_handle *)obj;
    if (listener_handle->listener >= 0) {
        close(listener_handle->listener);
        listener_handle->listener = -1;
    }
}

// NIF initialization
static int load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM load_info) {
    int flags = ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER;
    
    tailscale_resource_type = 
        enif_open_resource_type(env, NULL, "tailscale_resource", 
                               tailscale_resource_dtor, flags, NULL);
    
    if (tailscale_resource_type == NULL) {
        return -1;
    }
    
    tailscale_listener_resource_type = 
        enif_open_resource_type(env, NULL, "tailscale_listener_resource", 
                               tailscale_listener_resource_dtor, flags, NULL);
    
    if (tailscale_listener_resource_type == NULL) {
        return -1;
    }
    
    return 0;
}

static int upgrade(ErlNifEnv *env, void **priv_data, void **old_priv_data, ERL_NIF_TERM load_info) {
    return 0;
}

static void unload(ErlNifEnv *env, void *priv_data) {
    // Any cleanup needed when the NIF is unloaded
}

// NIF function registration
static ErlNifFunc nif_funcs[] = {
    // Core functions
    {"tailscale_new", 0, tailscale_new_nif, 0},
    {"tailscale_start", 1, tailscale_start_nif, 0},
    {"tailscale_up", 1, tailscale_up_nif, ERL_NIF_DIRTY_JOB_IO_BOUND}, // Potentially blocking
    {"tailscale_close", 1, tailscale_close_nif, 0},
    {"tailscale_errmsg", 2, tailscale_errmsg_nif, 0},
    
    // Configuration functions
    {"tailscale_set_dir", 2, tailscale_set_dir_nif, 0},
    {"tailscale_set_hostname", 2, tailscale_set_hostname_nif, 0},
    {"tailscale_set_authkey", 2, tailscale_set_authkey_nif, 0},
    {"tailscale_set_control_url", 2, tailscale_set_control_url_nif, 0},
    {"tailscale_set_ephemeral", 2, tailscale_set_ephemeral_nif, 0},
    {"tailscale_set_logfd", 2, tailscale_set_logfd_nif, 0},
    
    // Networking functions
    {"tailscale_dial", 3, tailscale_dial_nif, ERL_NIF_DIRTY_JOB_IO_BOUND}, // Potentially blocking
    {"tailscale_listen", 3, tailscale_listen_nif, 0},
    {"tailscale_accept", 1, tailscale_accept_nif, ERL_NIF_DIRTY_JOB_IO_BOUND}, // Blocking
    {"tailscale_getips", 2, tailscale_getips_nif, 0},
    {"tailscale_getremoteaddr", 3, tailscale_getremoteaddr_nif, 0},
    
    // LocalAPI and funnel functions
    {"tailscale_loopback", 2, tailscale_loopback_nif, 0},
    {"tailscale_enable_funnel", 2, tailscale_enable_funnel_nif, 0}
};

ERL_NIF_INIT(Tailscale.NIF, nif_funcs, load, NULL, upgrade, unload)