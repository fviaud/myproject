package main

import (
	"fmt"
	"log"

	"backend/internal/database"
	"backend/internal/router"

	"github.com/joho/godotenv"
)

func main() {

	err := godotenv.Load()
	if err != nil {
		log.Fatalf("Error loading .env file: %v", err)
	}

	client := database.GetClient()
	defer database.CloseConnection()
	fmt.Printf("Database connection established: %v\n", client != nil)

	r := router.New(client)

	addr := ":8080"
	log.Printf("Server starting on %s", addr)
	if err := r.Run(addr); err != nil {
		log.Fatal(err)
	}
}
