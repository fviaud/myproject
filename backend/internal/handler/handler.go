package handler

import (
	"net/http"
	"sync"

	"backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type Handler struct {
	mu    sync.RWMutex
	items map[string]models.Product
}

func New() *Handler {
	return &Handler{
		items: make(map[string]models.Product),
	}
}

func (h *Handler) Health(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}

func (h *Handler) ListItems(c *gin.Context) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	items := make([]models.Product, 0, len(h.items))
	for _, item := range h.items {
		items = append(items, item)
	}
	c.JSON(http.StatusOK, items)
}

func (h *Handler) CreateItem(c *gin.Context) {
	var newProduct models.Product
	if err := c.ShouldBindJSON(&newProduct); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	for _, p := range h.items {
		if p.Name == newProduct.Name {
			c.JSON(http.StatusConflict, gin.H{"error": "name already exists"})
			return
		}
	}

	h.mu.Lock()
	defer h.mu.Unlock()

	id := uuid.New()
	newProduct.ID = id
	h.items[id.String()] = newProduct
	c.JSON(http.StatusCreated, newProduct)
}

func (h *Handler) GetItem(c *gin.Context) {
	id := c.Param("id")

	h.mu.RLock()
	defer h.mu.RUnlock()

	item, ok := h.items[id]
	if !ok {
		c.JSON(http.StatusNotFound, gin.H{"error": "item not found"})
		return
	}
	c.JSON(http.StatusOK, item)
}

func (h *Handler) UpdateItem(c *gin.Context) {
	id := c.Param("id")

	var item models.Product
	if err := c.ShouldBindJSON(&item); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}
	parsedID, err := uuid.Parse(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id format"})
		return
	}
	item.ID = parsedID

	h.mu.Lock()
	defer h.mu.Unlock()

	if _, exists := h.items[id]; !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "item not found"})
		return
	}
	h.items[id] = item
	c.JSON(http.StatusOK, item)
}

func (h *Handler) DeleteItem(c *gin.Context) {
	id := c.Param("id")

	h.mu.Lock()
	defer h.mu.Unlock()

	if _, exists := h.items[id]; !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "item not found"})
		return
	}
	delete(h.items, id)
	c.Status(http.StatusNoContent)
}
