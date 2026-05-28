package models

import (
	"time"

	"github.com/google/uuid"
)

type Todo struct {
	ID        uuid.UUID `json:"id" gorm:"type:uuid;primaryKey"`
	Title     string    `json:"title" gorm:"uniqueIndex;not null"`
	Completed bool      `json:"completed" gorm:"default:false"`
	CreatedAt time.Time `json:"created_at" gorm:"autoCreateTime"`
	UpdatedAt time.Time `json:"updated_at" gorm:"autoUpdateTime"`
}

type UpdateTodoInput struct {
	Title     *string `json:"title"`
	Completed *bool   `json:"completed"`
}
