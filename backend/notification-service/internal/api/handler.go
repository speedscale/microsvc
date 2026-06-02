package api

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
	"github.com/speedscale/microsvc/notification-service/internal/consumer"
)

const defaultLimit = 20

// Handler wires HTTP routes to the shared ring buffer.
type Handler struct {
	buf *consumer.RingBuffer
}

func NewHandler(buf *consumer.RingBuffer) http.Handler {
	h := &Handler{buf: buf}
	r := mux.NewRouter()
	r.HandleFunc("/health", h.health).Methods(http.MethodGet)
	r.HandleFunc("/notifications", h.list).Methods(http.MethodGet)
	r.HandleFunc("/notifications/{user_id}", h.byUser).Methods(http.MethodGet)
	return r
}

func (h *Handler) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
	limit := parseLimit(r, defaultLimit)
	writeJSON(w, http.StatusOK, h.buf.Latest(limit))
}

func (h *Handler) byUser(w http.ResponseWriter, r *http.Request) {
	userID := mux.Vars(r)["user_id"]
	limit := parseLimit(r, defaultLimit)
	writeJSON(w, http.StatusOK, h.buf.ForUser(userID, limit))
}

func parseLimit(r *http.Request, def int) int {
	if s := r.URL.Query().Get("limit"); s != "" {
		if n, err := strconv.Atoi(s); err == nil && n > 0 {
			return n
		}
	}
	return def
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(v)
}
