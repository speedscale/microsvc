import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;

// Minimal repro driver for S-10292: does the nettap JVM agent break outbound
// TLS done via java.net.http.HttpClient? Loops HTTPS GETs against a live
// third-party API (US Treasury fiscal data) and logs success or the exact
// exception. Run with and without -javaagent to compare.
public class TreasuryClient {
    public static void main(String[] args) throws Exception {
        String url = "https://api.fiscaldata.treasury.gov/services/api/fiscal_service"
                + "/v2/accounting/od/avg_interest_rates?sort=-record_date&page[size]=1";
        String mode = System.getenv().getOrDefault("REPRO_MODE", "unknown");
        // When true, build a fresh HttpClient each iteration so every request
        // performs a full TLS handshake (the path S-10292 broke), instead of
        // reusing a pooled keep-alive connection.
        boolean freshClient = Boolean.parseBoolean(System.getenv().getOrDefault("FRESH_CLIENT", "false"));
        System.out.println("[treasury] starting client mode=" + mode + " freshClient=" + freshClient
                + " jdk=" + System.getProperty("java.version"));

        HttpClient shared = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
        HttpRequest req = HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(15))
                .header("Accept", "application/json")
                .GET()
                .build();

        int ok = 0, fail = 0, i = 0;
        while (true) {
            i++;
            Instant t0 = Instant.now();
            try {
                HttpClient client = freshClient
                        ? HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build()
                        : shared;
                HttpResponse<String> resp = client.send(req, HttpResponse.BodyHandlers.ofString());
                long ms = Duration.between(t0, Instant.now()).toMillis();
                ok++;
                System.out.println("[treasury] #" + i + " OK status=" + resp.statusCode()
                        + " bytes=" + resp.body().length() + " ms=" + ms
                        + " (ok=" + ok + " fail=" + fail + ")");
            } catch (Exception e) {
                long ms = Duration.between(t0, Instant.now()).toMillis();
                fail++;
                Throwable root = e;
                while (root.getCause() != null) root = root.getCause();
                System.out.println("[treasury] #" + i + " FAIL ms=" + ms
                        + " ex=" + e.getClass().getName() + " msg=" + e.getMessage()
                        + " root=" + root.getClass().getName() + ":" + root.getMessage()
                        + " (ok=" + ok + " fail=" + fail + ")");
            }
            Thread.sleep(3000);
        }
    }
}
