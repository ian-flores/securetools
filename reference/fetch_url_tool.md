# Create a URL fetch tool

Returns a
[`securer::securer_tool()`](https://ian-flores.github.io/securer/reference/securer_tool.html)
that fetches content from URLs via HTTP GET/HEAD with domain allow-lists
and rate limiting.

## Usage

``` r
fetch_url_tool(
  allowed_domains,
  max_response_size = "1MB",
  timeout_secs = 30,
  max_calls = NULL,
  max_calls_per_minute = 10
)
```

## Arguments

- allowed_domains:

  Character vector of allowed domains (required). Use `*.example.com`
  for wildcard subdomains matching any subdomain but not the bare domain
  itself.

- max_response_size:

  Maximum response body size. Default `"1MB"`.

- timeout_secs:

  Request timeout in seconds. Default 30.

- max_calls:

  Maximum lifetime invocations. `NULL` means unlimited.

- max_calls_per_minute:

  Maximum invocations per 60-second window. Default 10.

## Value

A `securer_tool` object.

## Details

The tool enforces several layers of security:

- **Protocol restriction**: Only `http` and `https` schemes are
  accepted. Other protocols (e.g. `file://`, `ftp://`) are rejected.

- **Private IP blocking**: Hostnames that resolve to private or reserved
  IP ranges (10.x, 172.16-31.x, 192.168.x, 127.x, 169.254.x, 0.0.0.0)
  are blocked to prevent SSRF attacks.

- **No redirect following**: HTTP redirects are not followed, preventing
  redirect-based SSRF bypasses.

- **Domain allow-list**: Every request is checked against the
  `allowed_domains` list. Wildcard entries like `*.example.com` match
  any subdomain (e.g. `api.example.com`, `deep.sub.example.com`) but not
  the bare `example.com`.

- **Curl-level size limit**: A `maxfilesize` curl option caps the
  download at `max_response_size` bytes, with an additional
  post-download `nchar` check as a backup.

- **Rate limiting**: Both per-minute and lifetime invocation limits are
  enforced.

## See also

[`securer_tool`](https://ian-flores.github.io/securer/reference/securer_tool.html)

Other tool factories:
[`calculator_tool()`](https://ian-flores.github.io/securetools/reference/calculator_tool.md),
[`data_profile_tool()`](https://ian-flores.github.io/securetools/reference/data_profile_tool.md),
[`plot_tool()`](https://ian-flores.github.io/securetools/reference/plot_tool.md),
[`query_sql_tool()`](https://ian-flores.github.io/securetools/reference/query_sql_tool.md),
[`r_help_tool()`](https://ian-flores.github.io/securetools/reference/r_help_tool.md),
[`read_file_tool()`](https://ian-flores.github.io/securetools/reference/read_file_tool.md),
[`write_file_tool()`](https://ian-flores.github.io/securetools/reference/write_file_tool.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tool <- fetch_url_tool(
  allowed_domains = c("api.example.com", "*.cdn.example.com"),
  max_response_size = "512KB",
  timeout_secs = 10
)
} # }
```
