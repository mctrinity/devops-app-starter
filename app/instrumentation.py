from prometheus_client import Counter, Histogram
from time import perf_counter

REQUESTS = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"],
)

LATENCY = Histogram(
    "http_request_duration_seconds",
    "Request latency",
    ["method", "endpoint"],
)

class TrackRequest:
    def __init__(self, method: str, endpoint: str):
        self.method = method
        self.endpoint = endpoint
        self.start = perf_counter()

    def done(self, status: int):
        REQUESTS.labels(self.method, self.endpoint, str(status)).inc()
        LATENCY.labels(self.method, self.endpoint).observe(
            perf_counter() - self.start
        )
