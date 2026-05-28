package models

import (
	"time"

	"github.com/google/uuid"
)

type Product struct {
  	ID    uuid.UUID `json:"id" gorm:"type:uuid;primaryKey"`
    Name  string    `json:"name" gorm:"uniqueIndex;not null"`
		Description string    `json:"description" gorm:"type:text"`
		Price       float64   `json:"price" gorm:"type:decimal(10,2);not null"`
		Stock       int       `json:"stock" gorm:"type:int;not null"`
		CreatedAt   time.Time `json:"created_at" gorm:"autoCreateTime"`
		UpdatedAt   time.Time `json:"updated_at" gorm:"autoUpdateTime"`
}