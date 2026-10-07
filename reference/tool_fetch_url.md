# Create a URL fetch tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that makes GET and HEAD requests to the domains you allow.

## Usage

``` r
tool_fetch_url(
  allowed_domains,
  max_response_size = "1MB",
  timeout_secs = 30,
  max_calls = NULL,
  max_calls_per_minute = 10
)
```

## Arguments

- allowed_domains:

  Character vector of domains the tool may contact. Required.
  `*.example.com` matches any subdomain of `example.com` but not
  `example.com` itself.

- max_response_size:

  The largest response body the tool will return. Default `"1MB"`.

- timeout_secs:

  How long to wait for a response, in seconds. Default 30.

- max_calls:

  The most times the tool can be called in total. `NULL` means no limit.

- max_calls_per_minute:

  The most calls allowed in any 60 seconds. Default 10.

## Value

A `securer_tool` object.

## Details

Only `http` and `https` URLs are accepted, and only GET and HEAD. The
host must match `allowed_domains`. For example, `*.example.com` matches
`api.example.com` and `deep.sub.example.com`, but not `example.com`.

The tool looks up the host's IP address once and refuses private and
reserved addresses (10.x, 172.16-31.x, 192.168.x, 127.x, 169.254.x, and
0.0.0.0) as well as every IPv6 address. It then connects to that IP
directly, with the original host name in the `Host` header, so a second
DNS lookup can't point it somewhere else. Redirects are not followed.

curl stops the download at `max_response_size`, and the body size is
checked again afterwards.

HTTPS requests currently fail: because the tool connects by IP address,
the server's TLS certificate doesn't match and curl rejects it.

## See also

[`securer_tool`](https://ian-flores.github.io/securer/reference/securer_tool.html)

Other tool factories:
[`tool_calculator()`](https://ian-flores.github.io/securetools/reference/tool_calculator.md),
[`tool_data_profile()`](https://ian-flores.github.io/securetools/reference/tool_data_profile.md),
[`tool_plot()`](https://ian-flores.github.io/securetools/reference/tool_plot.md),
[`tool_query_sql()`](https://ian-flores.github.io/securetools/reference/tool_query_sql.md),
[`tool_r_help()`](https://ian-flores.github.io/securetools/reference/tool_r_help.md),
[`tool_read_file()`](https://ian-flores.github.io/securetools/reference/tool_read_file.md),
[`tool_write_file()`](https://ian-flores.github.io/securetools/reference/tool_write_file.md)

## Examples

``` r
# \donttest{
tool <- tool_fetch_url(
  allowed_domains = c("api.example.com", "*.cdn.example.com"),
  max_response_size = "512KB",
  timeout_secs = 10
)
# }
```
