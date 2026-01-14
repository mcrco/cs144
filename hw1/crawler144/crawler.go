package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"golang.org/x/net/html"
)

type Crawler struct {
	agentName    string
	domain       string
	filename     string
	visited      map[string]struct{}
	visitedMutex sync.Mutex
	file         *os.File
	fileMutex    sync.Mutex
	robots       *RobotsManager
}

type QueueItem struct {
	urlString string
	depth     int
}

func NewCrawler(domain string, filename string) (*Crawler, error) {
	visited := make(map[string]struct{})

	file, err := os.Create(filename)
	if err != nil {
		return nil, fmt.Errorf("failed to create file: %w", err)
	}

	crawler := &Crawler{
		agentName: "crawler144",
		domain:    domain,
		filename:  filename,
		visited:   visited,
		file:      file,
	}

	return crawler, nil
}

func (c *Crawler) Crawl(root string, numWorkers int, maxDepth int, maxPages int, respectCrawlDelay bool) {
	queue := make(chan QueueItem, maxPages)
	var wg sync.WaitGroup

	if c.robots == nil {
		c.robots = NewRobotsManager(c.agentName, root)
	}

	if !c.robots.Allowed(root) {
		fmt.Printf("Root URL disallowed by robots.txt: %s\n", root)
		_ = c.file.Close()
		return
	}

	queue <- QueueItem{urlString: root, depth: 0}
	wg.Add(1)
	c.hasVisitedOrMark(root)

	for range numWorkers {
		go func() {
			for item := range queue {
				urlString := item.urlString
				depth := item.depth

				if respectCrawlDelay {
					time.Sleep(time.Duration(c.robots.crawlDelay) * time.Second)
				}

				if !c.robots.Allowed(urlString) {
					wg.Done()
					continue
				}

				children, err := c.extractChildrenUrls(urlString)
				if err != nil {
					fmt.Printf("failed to extract children urls: %v for url: %s\n", err, urlString)
					wg.Done()
					continue
				}
				c.saveChildrenToFile(urlString, children)
				for _, next := range children {
					if depth < maxDepth && c.visitedCount() < maxPages && c.robots.Allowed(next) && !c.hasVisitedOrMark(next) {
						queue <- QueueItem{urlString: next, depth: depth + 1}
						wg.Add(1)
					}
				}
				wg.Done()
			}
		}()
	}

	wg.Wait()
	close(queue)
	_ = c.file.Close()
	fmt.Printf("Crawled %d pages\n", c.visitedCount())
	fmt.Printf("Saved crawl results to %s\n", c.filename)
}

func (c *Crawler) visitedCount() int {
	c.visitedMutex.Lock()
	defer c.visitedMutex.Unlock()
	return len(c.visited)
}

func (c *Crawler) hasVisitedOrMark(u string) bool {
	c.visitedMutex.Lock()
	defer c.visitedMutex.Unlock()

	if _, seen := c.visited[u]; seen {
		return true
	}
	c.visited[u] = struct{}{}
	return false
}

func (c *Crawler) extractChildrenUrls(urlString string) ([]string, error) {
	u, err := url.Parse(urlString)
	if err != nil {
		return nil, fmt.Errorf("failed to parse raw url: %w", err)
	}
	// Normalize the url to not include fragment (e.g. "#content") so we don't treat
	// "same-page anchors" as distinct URLs.
	u.Fragment = ""

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Get(urlString)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("status code %d for url: %s", resp.StatusCode, urlString)
	}

	var extractedUrls []string
	tokenizer := html.NewTokenizer(resp.Body)
	for {
		tokenType := tokenizer.Next()
		if tokenType == html.ErrorToken {
			break
		}

		token := tokenizer.Token()
		if token.Type == html.StartTagToken && token.Data == "a" {
			for _, attr := range token.Attr {
				if attr.Key == "href" {
					normalized := c.normalizeUrl(attr.Val, u)
					if normalized != "" {
						extractedUrls = append(extractedUrls, normalized)
					}
				}
			}
		}
	}

	return extractedUrls, nil
}

func (c *Crawler) normalizeUrl(href string, orig *url.URL) string {
	href = strings.TrimSpace(href)
	if href == "" {
		return ""
	}
	// Skip same-page anchor links like "#content" on "https://caltech.edu#content".
	if strings.HasPrefix(href, "#") {
		return ""
	}

	u, err := url.Parse(href)
	if err != nil {
		return ""
	}

	// Skip non-HTTP(S) schemes that aren't crawlable.
	// Note: for relative links, u.Scheme == "" and we allow it.
	if u.Scheme != "" && u.Scheme != "http" && u.Scheme != "https" {
		return ""
	}

	resolved := orig.ResolveReference(u)
	resolved.Fragment = ""

	if !c.checkDomain(resolved) {
		return ""
	}

	return resolved.String()
}

func (c *Crawler) checkDomain(u *url.URL) bool {
	host := u.Hostname()
	return c.domain == host || strings.HasSuffix(host, "."+c.domain)
}

type CrawlRecord struct {
	URL      string   `json:"url"`
	Children []string `json:"children"`
}

func (c *Crawler) saveChildrenToFile(urlString string, children []string) {
	c.fileMutex.Lock()
	defer c.fileMutex.Unlock()

	rec := CrawlRecord{URL: urlString, Children: children}
	lineBytes, err := json.Marshal(rec)
	if err != nil {
		fmt.Printf("failed to marshal record: %v for url: %s\n", err, urlString)
		return
	}
	_, err = c.file.Write(append(lineBytes, '\n'))
	if err != nil {
		fmt.Printf("failed to write record to file: %v for url: %s\n", err, urlString)
	}
}
