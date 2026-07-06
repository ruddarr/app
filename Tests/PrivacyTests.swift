import Testing
import Foundation

struct PrivacyTests {
    @Test func masksSubdomainLabelsButKeepsTheTLD() {
        #expect(maskedURL("https://radarr.mydomainfoo.com:7878/api/v3/movie?term=dune")
            == "https://rad***.mydoma*****.com:7878/api/v3/movie?term=dune")
        #expect(maskedURL("http://radarr.myddns.net:7878/api/v3/movie")
            == "http://rad***.myd***.net:7878/api/v3/movie")
    }

    @Test func keepsNetworkCategorySuffixesAndMasksTheLabelsBeforeThem() {
        #expect(maskedURL("http://nas.local:8989/api/v3/series") == "http://na*.local:8989/api/v3/series")
        #expect(maskedURL("https://box.tailnet.ts.net/api/v3/movie") == "https://bo*.tail***.ts.net/api/v3/movie")
    }

    @Test func masksOnlyTheHostOctetOfPrivateIPv4() {
        // Private addresses are non-routable, so the subnet octet identifies nobody — and
        // keeping it lets a diagnostics report show a device/server subnet mismatch.
        #expect(maskedURL("http://192.168.1.50:7878/api/v3/movie") == "http://192.168.1.*:7878/api/v3/movie")
        #expect(maskedURL("http://10.0.1.5/x") == "http://10.0.1.*/x")
        #expect(maskedURL("http://172.16.32.9/x") == "http://172.16.32.*/x")
        #expect(maskedURL("http://169.254.7.3/x") == "http://169.254.7.*/x") // link-local
        #expect(maskedURL("http://127.0.0.1:7878/x") == "http://127.0.0.1:7878/x") // loopback kept
    }

    @Test func keepsFirstTwoOctetsOfRoutableIPv4() {
        #expect(maskedURL("http://100.100.3.7:7878/x") == "http://100.100.*.*:7878/x") // Tailscale CGNAT
        #expect(maskedURL("https://203.0.113.9/api/v3/movie") == "https://203.0.*.*/api/v3/movie") // public: a little shown
    }

    @Test func keepsFirstIPv6Group() {
        #expect(maskedURL("http://[fe80::1]:8989/x") == "http://[fe80::*]:8989/x")
        #expect(maskedURL("http://[fd7a:115c:a1e0::1]:8989/x") == "http://[fd7a:115c:a1e0::*]:8989/x") // Tailscale
        #expect(maskedURL("https://[2600:1700:abcd:1::50]/x") == "https://[2600::*]/x")                 // global: a little shown
    }

    @Test func masksUserinfoAndHostKeepingPathAndQuery() {
        // Credentials are fully replaced by five stars each, regardless of their length.
        #expect(maskedURL("https://user:pass@radarr.myddns.net/api/v3/movie?term=dune&page=2")
            == "https://*****:*****@rad***.myd***.net/api/v3/movie?term=dune&page=2")
        #expect(maskedURL("http://admin:supersecretlongpassword@10.0.1.5:7878/x")
            == "http://*****:*****@10.0.1.*:7878/x")
        // Username only, no password.
        #expect(maskedURL("http://tokenonly@nas.local:8989/api")
            == "http://*****@na*.local:8989/api")
        // A username equal to the host no longer leaks the real host (rebuilt from the authority
        // component, not a first-occurrence string search).
        #expect(maskedURL("https://radarr.myddns.net@radarr.myddns.net/api")
            == "https://*****@rad***.myd***.net/api")
    }

    @Test func masksSubnetCIDRsWithTheSamePolicyAsHosts() {
        #expect(maskedCIDR("192.168.42.0/24") == "192.168.42.*/24")
        #expect(maskedCIDR("10.0.1.0/24") == "10.0.1.*/24")
        #expect(maskedCIDR("2001:db8:abcd:1:0:0:0:0/64") == "2001::*/64")
    }

    @Test func hidesInlineCredentialsButKeepsTopologyVerbatim() {
        // The unmasked diagnostics export shows topology in full but must never reveal a stored
        // password: userinfo is redacted while scheme/host/port/path stay exactly as configured.
        #expect(urlHidingUserinfo("http://admin:supersecretlongpassword@10.0.1.5:7878/api")
            == "http://*****:*****@10.0.1.5:7878/api")
        #expect(urlHidingUserinfo("http://tokenonly@nas.local:8989/api")
            == "http://*****@nas.local:8989/api")
        // No credentials → returned unchanged, so ordinary URLs stay byte-for-byte intact.
        #expect(urlHidingUserinfo("https://radarr.example.com/api/v3/movie?term=dune")
            == "https://radarr.example.com/api/v3/movie?term=dune")
        #expect(urlHidingUserinfo("http://192.168.1.50:7878/api/v3/movie")
            == "http://192.168.1.50:7878/api/v3/movie")
    }
}
