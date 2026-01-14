package main

import (
	"flag"
	"fmt"
	"os"
)

func main() {
	domainPtr := flag.String("domain", "caltech.edu", "The domain to crawl on")
	rootPtr := flag.String("root", "https://caltech.edu", "The root url to start crawling on")
	workerPtr := flag.Int("workers", 8, "Number of concurrent workers")
	depthPtr := flag.Int("depth", 10, "Maximum number of pages to crawl")
	pagesPtr := flag.Int("pages", 100000, "Maximum number of pages to crawl")
	filenamePtr := flag.String("output", "graph.jsonl", "Output JSONL file name (one record per line)")
	crawlDelayPtr := flag.Bool("respect-crawl-delay", false, "Respect crawl delay in robots.txt (accidentally leave off for speedups!)")

	flag.Parse()

	fmt.Printf("Starting crawl on: %s\n", *rootPtr)
	crawler, err := NewCrawler(*domainPtr, *filenamePtr)
	if err != nil {
		fmt.Printf("Error creating crawler: %v\n", err)
		os.Exit(1)
	}
	crawler.Crawl(*rootPtr, *workerPtr, *depthPtr, *pagesPtr, *crawlDelayPtr)
}
