package handler

import (
	"backend/internal/models"

	"errors"
	"fmt"
	"net/http"
	"sync"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type TodoHandler struct {
	mu    sync.RWMutex
	items map[string]models.Todo
	db    *gorm.DB
}

func NewTodoHandler(db *gorm.DB) *TodoHandler {
	return &TodoHandler{
		items: make(map[string]models.Todo),
		db:    db,
	}
}

func (h *TodoHandler) Health(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}

func (h *TodoHandler) ListItems(c *gin.Context) {
	// Pagination params
	page := 1
	pageSize := 10
	if p := c.Query("page"); p != "" {
		fmt.Sscanf(p, "%d", &page)
		if page < 1 {
			page = 1
		}
	}
	if ps := c.Query("pageSize"); ps != "" {
		fmt.Sscanf(ps, "%d", &pageSize)
		if pageSize < 1 || pageSize > 100 {
			pageSize = 10
		}
	}

	var todos []models.Todo
	var total int64
	h.db.Model(&models.Todo{}).Count(&total)
	offset := (page - 1) * pageSize
	if err := h.db.Limit(pageSize).Offset(offset).Order("created_at desc").Find(&todos).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch todos"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"items":    todos,
		"total":    total,
		"page":     page,
		"pageSize": pageSize,
	})
}

func (h *TodoHandler) CreateItem(c *gin.Context) {
	var newTodo models.Todo
	if err := c.ShouldBindJSON(&newTodo); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}
	newTodo.ID = uuid.New()
	if err := h.db.Create(&newTodo).Error; err != nil {

		if errors.Is(err, gorm.ErrDuplicatedKey) {
			c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		}
		return
	}
	c.JSON(http.StatusCreated, newTodo)
}

func (h *TodoHandler) GetItem(c *gin.Context) {
	id := c.Param("id")
	fmt.Printf("Fetching todo with ID: %s\n", id)
	var item models.Todo
	if err := h.db.First(&item, "id = ?", id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "todo not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch todo"})
		}
		return
	}
	c.JSON(http.StatusOK, item)
}

func (h *TodoHandler) UpdateItem(c *gin.Context) {
	id := c.Param("id")
	var item models.UpdateTodoInput
	if err := c.ShouldBindJSON(&item); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}
	result := h.db.Model(&models.Todo{}).Where("id = ?", id).Updates(item)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": result.Error.Error()})
		return
	}
	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "todo not found"})
		return
	}

	var updated models.Todo
	h.db.First(&updated, "id = ?", id)
	c.JSON(http.StatusOK, updated)
}

func (h *TodoHandler) DeleteItem(c *gin.Context) {
	id := c.Param("id")

	_, err := uuid.Parse(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id format"})
		return
	}

	result := h.db.Delete(&models.Todo{}, "id = ?", id)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to delete todo"})
		return
	}
	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "todo not found"})
		return
	}
	c.Status(http.StatusNoContent)
}
