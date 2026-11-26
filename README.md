# MyRuleSet

自用分流规则集，同时覆盖 Clash、Loon 和 sing-box。

## 目录

| 路径 | 内容 |
| --- | --- |
| `ACL4SSR/Clash/` | Clash 规则列表 |
| `ACL4SSR/Loon/` | Loon 规则列表 |
| `sing-box/` | 规则源（`*.json`）与编译产物（`*.srs`） |
| `sing-box/config_template/` | sing-box 配置模板，线上配置由订阅转换按模板生成 |
| `subconvert/FULL.ini` | subconverter 配置 |
| `scripts/update-pin.sh` | 把模板里的规则集引用固定到当前 commit |

## 改完 sing-box 规则之后

```bash
# 1. 编译
sing-box rule-set compile sing-box/archlinux.json -o sing-box/archlinux.srs

# 2. 提交规则本体
git add sing-box/archlinux.json sing-box/archlinux.srs
git commit -m "fix(rules): ..."

# 3. 把模板里的引用固定到这次 commit，再提交
./scripts/update-pin.sh
git add -A && git commit -m "chore: pin rule sets to latest commit"
git push
```

模板里的自定义规则集使用 commit hash 而不是 `@main`：jsdelivr 对 `@branch`
的缓存 `s-maxage` 是 12 小时（`testingcf` 节点尤其顽固，purge 也未必立刻生效），
只有 pin 到具体 commit 的路径才会立刻回源取到新版本。

## sing-box 1.14 的配置约束

DNS 规则里一旦出现 `query_type` 或 `ip_version`，整个 `dns.rules` 就不能再
包含 legacy 地址过滤字段（把 `rule_set` 直接当 IP 匹配用，例如 `geoip-cn`），
否则进程启动即失败：

```
FATAL start service: start router: initialize rule-set[..]: validate dns rule[n]:
sub rule[1]: Legacy Address Filter Fields in DNS rules is deprecated in sing-box 1.14.0
```

模板里原本有一条这样的规则（「不在境外列表，但解析出中国 IP → 用 google 复核」），
现已按官方迁移指南改成 `evaluate` + `match_response`：

```json
{
  "rule_set": "geosite-geolocation-!cn",
  "invert": true,
  "action": "evaluate",
  "server": "google",
  "tag": "google-response",
  "client_subnet": "114.114.114.114/24"
},
{
  "match_response": "google-response",
  "rule_set": "geoip-cn",
  "action": "respond"
}
```

`evaluate` 只能写在顶层规则上，不终止匹配；`match_response` 用 evaluate 的 tag
引用它的响应，`respond` 直接把该响应返回。这样 `geoip-cn` 不再是裸的地址过滤
字段，`query_type` 才能共存。

改完之后模板就能在 DNS 层拦截 AAAA 了：

```json
{ "query_type": ["AAAA"], "action": "predefined", "rcode": "NOERROR" }
```

用 `predefined` + `NOERROR` 返回空答案（NODATA），客户端会干净地退回 A 记录；
如果用 `reject`，拿到的是 REFUSED，某些客户端会重试或直接失败。

节点侧的 IPv6 出口对 Fastly、Cloudflare、Google 这些前缀普遍不通，而本机直连的
IPv6 是好的，所以只在走节点时才有问题。DNS 层拦掉 AAAA 可以一次性绕开。

## 节点分组过滤

`Proxy`、`auto`、`Streaming`、`Download` 四组共用同一份排除词，用来挡掉订阅里
的信息节点（`Traffic: 17.59 GB`、`Expire: 2027-03-23` 之类）：

```
网站|地址|剩余|过期|时间|有效|当前流量|重置|到期|Traffic:|Expire:
```

改动任意一组时请同步其余三组，否则信息节点会从漏改的那组混进来。
