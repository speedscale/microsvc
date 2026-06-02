import com.sun.net.httpserver.HttpsConfigurator;
import com.sun.net.httpserver.HttpsServer;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.security.KeyStore;
import java.security.SecureRandom;
import java.security.cert.X509Certificate;
import java.time.Duration;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicLong;
import javax.net.ssl.*;

// High-volume in-process TLS load driver. Stands up an HTTPS server on
// localhost and pounds it with many client threads over TLS, so ALL the
// SSLEngine/SSLSocket wrap+unwrap traffic flows through the nettap JVM agent's
// hooks at high throughput. Mimics the sustained encrypted span-export stream
// an OTEL exporter produces. Run with and without -javaagent to compare.
public class TlsLoad {
    static final AtomicLong ok = new AtomicLong();
    static final AtomicLong fail = new AtomicLong();
    static final AtomicLong bytes = new AtomicLong();

    public static void main(String[] args) throws Exception {
        int threads = Integer.parseInt(System.getenv().getOrDefault("THREADS", "32"));
        int bodyBytes = Integer.parseInt(System.getenv().getOrDefault("BODY_BYTES", "4096"));
        String mode = System.getenv().getOrDefault("REPRO_MODE", "unknown");
        String ksPath = System.getenv().getOrDefault("KEYSTORE", "/tmp/ks.p12");
        char[] pass = System.getenv().getOrDefault("KEYSTORE_PASS", "changeit").toCharArray();
        System.out.println("[tlsload] mode=" + mode + " threads=" + threads
                + " bodyBytes=" + bodyBytes + " jdk=" + System.getProperty("java.version"));

        // ---- server SSLContext from keystore ----
        KeyStore ks = KeyStore.getInstance("PKCS12");
        try (var in = new java.io.FileInputStream(ksPath)) { ks.load(in, pass); }
        KeyManagerFactory kmf = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
        kmf.init(ks, pass);
        SSLContext serverCtx = SSLContext.getInstance("TLS");
        serverCtx.init(kmf.getKeyManagers(), null, new SecureRandom());

        byte[] body = new byte[bodyBytes];
        java.util.Arrays.fill(body, (byte) 'x');

        HttpsServer server = HttpsServer.create(new InetSocketAddress(8443), 0);
        server.setHttpsConfigurator(new HttpsConfigurator(serverCtx));
        server.createContext("/spans", ex -> {
            try (ex) {
                // drain request body (simulate receiving a span batch)
                ex.getRequestBody().readAllBytes();
                ex.sendResponseHeaders(200, body.length);
                try (OutputStream os = ex.getResponseBody()) { os.write(body); }
            } catch (Exception ignore) {}
        });
        server.setExecutor(Executors.newFixedThreadPool(Math.max(8, threads)));
        server.start();

        // ---- client: trust-all (load test, self-signed) ----
        TrustManager[] trustAll = { new X509TrustManager() {
            public void checkClientTrusted(X509Certificate[] c, String a) {}
            public void checkServerTrusted(X509Certificate[] c, String a) {}
            public X509Certificate[] getAcceptedIssuers() { return new X509Certificate[0]; }
        }};
        SSLContext clientCtx = SSLContext.getInstance("TLS");
        clientCtx.init(null, trustAll, new SecureRandom());

        byte[] payload = new byte[bodyBytes];
        java.util.Arrays.fill(payload, (byte) 'p');
        URI uri = URI.create("https://localhost:8443/spans");

        Runnable worker = () -> {
            HttpClient client = HttpClient.newBuilder().sslContext(clientCtx)
                    .connectTimeout(Duration.ofSeconds(5)).build();
            while (true) {
                try {
                    HttpRequest req = HttpRequest.newBuilder(uri)
                            .timeout(Duration.ofSeconds(10))
                            .POST(HttpRequest.BodyPublishers.ofByteArray(payload)).build();
                    HttpResponse<byte[]> r = client.send(req, HttpResponse.BodyHandlers.ofByteArray());
                    if (r.statusCode() == 200) { ok.incrementAndGet(); bytes.addAndGet(r.body().length); }
                    else fail.incrementAndGet();
                } catch (Exception e) {
                    long f = fail.incrementAndGet();
                    if (f <= 50 || f % 200 == 0) {
                        Throwable root = e; while (root.getCause() != null) root = root.getCause();
                        System.out.println("[tlsload] FAIL#" + f + " ex=" + e.getClass().getSimpleName()
                                + " msg=" + e.getMessage() + " root=" + root.getClass().getName()
                                + ":" + root.getMessage());
                    }
                }
            }
        };
        for (int i = 0; i < threads; i++) new Thread(worker, "load-" + i).start();

        // reporter
        long lastOk = 0, lastT = System.nanoTime();
        while (true) {
            Thread.sleep(2000);
            long o = ok.get(), f = fail.get();
            long now = System.nanoTime();
            double secs = (now - lastT) / 1e9;
            double rate = (o - lastOk) / secs;
            System.out.printf("[tlsload] ok=%d fail=%d rate=%.0f req/s mib=%.1f%n",
                    o, f, rate, bytes.get() / 1048576.0);
            lastOk = o; lastT = now;
        }
    }
}
