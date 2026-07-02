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

    @Test func keepsFirstTwoIPv4Octets() {
        #expect(maskedURL("http://192.168.1.50:7878/api/v3/movie") == "http://192.168.*.*:7878/api/v3/movie")
        #expect(maskedURL("http://10.0.1.5/x") == "http://10.0.*.*/x")
        #expect(maskedURL("http://100.100.3.7:7878/x") == "http://100.100.*.*:7878/x") // Tailscale CGNAT
        #expect(maskedURL("http://127.0.0.1:7878/x") == "http://127.0.0.1:7878/x")     // loopback kept
        #expect(maskedURL("https://203.0.113.9/api/v3/movie") == "https://203.0.*.*/api/v3/movie") // public: a little shown
    }

    @Test func keepsFirstIPv6Group() {
        #expect(maskedURL("http://[fe80::1]:8989/x") == "http://[fe80::*]:8989/x")
        #expect(maskedURL("http://[fd7a:115c:a1e0::1]:8989/x") == "http://[fd7a:115c:a1e0::*]:8989/x") // Tailscale
        #expect(maskedURL("https://[2600:1700:abcd:1::50]/x") == "https://[2600::*]/x")                 // global: a little shown
    }

    @Test func masksOnlyTheHostLeavingUserinfoAndQuery() {
        #expect(maskedURL("https://user:pass@radarr.myddns.net/api/v3/movie?term=dune&page=2")
            == "https://user:pass@rad***.myd***.net/api/v3/movie?term=dune&page=2")
    }
}
