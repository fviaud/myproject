package database

import (
	"os"
	"sync"

	"backend/internal/models"

	"gorm.io/driver/postgres" // or mysql, sqlite depending on your database
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var (
	db   *gorm.DB
	once sync.Once
)

// GetDB returns a singleton instance of the database connection
func GetClient() *gorm.DB {
	once.Do(func() {
		dbURL := os.Getenv("DATABASE_URL")
		if dbURL == "" {
			panic("DATABASE_URL environment variable is not set")
		}

		var err error
		db, err = gorm.Open(postgres.Open(dbURL), &gorm.Config{
			Logger: logger.Default.LogMode(logger.Silent),
		})
		if err != nil {
			panic("Failed to connect to database using DATABASE_URL: " + err.Error())

		}

		// Migrate models in the correct order (referenced tables first)
		db.AutoMigrate(&models.Todo{})

	})
	return db
}

// CloseConnection closes the database connection
func CloseConnection() {
	if db != nil {
		sqlDB, err := db.DB()
		if err != nil {
			panic("Failed to get underlying SQL DB: " + err.Error())
		}
		if err := sqlDB.Close(); err != nil {
			panic("Failed to close database connection: " + err.Error())
		}
	}
}
