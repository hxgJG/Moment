package main

import (
	"fmt"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	h := []byte("$2a$10$/cYZ8Vwwvu709T2C6qWQ0.3ukW.G7oUfRwp1ybbb/lT3Pu7B1HSbK")
	fmt.Println(bcrypt.CompareHashAndPassword(h, []byte("admin123")) == nil)
}
