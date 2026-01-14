package main

import (
	"bufio"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"
)

type RobotsTxt struct {
	Groups     []Group
	CrawlDelay int
}

type Group struct {
	Agents []string
	Rules  []Rule
}

type Rule struct {
	Path   string
	Allow  bool
	Regexp *regexp.Regexp
}

func ParseRobotsTxt(r io.Reader) *RobotsTxt {
	robotsTxt := &RobotsTxt{}
	var currentGroup *Group

	scanner := bufio.NewScanner(r)
	for scanner.Scan() {
		line := scanner.Text()
		if idx := strings.Index(line, "#"); idx != -1 {
			line = line[:idx]
		}
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		parts := strings.SplitN(line, ":", 2)
		if len(parts) < 2 {
			continue
		}
		key := strings.ToLower(strings.TrimSpace(parts[0]))
		val := strings.TrimSpace(parts[1])

		switch key {
		case "user-agent":
			if currentGroup == nil || len(currentGroup.Rules) > 0 {
				robotsTxt.Groups = append(robotsTxt.Groups, Group{})
				currentGroup = &robotsTxt.Groups[len(robotsTxt.Groups)-1]
			}
			currentGroup.Agents = append(currentGroup.Agents, strings.ToLower(val))

		case "disallow", "allow":
			if currentGroup == nil {
				continue
			}
			rule := Rule{
				Path:  val,
				Allow: (key == "allow"),
			}
			// Convert robots.txt wildcards to standard regex:
			// * -> .*
			pattern := regexp.QuoteMeta(val)
			pattern = strings.ReplaceAll(pattern, `\*`, `.*`)
			// We unintentionally escaped the $ character above, so we need to unescape it now.
			if strings.HasSuffix(pattern, `$`) {
				pattern = pattern[:len(pattern)-2] + `$`
			}
			rule.Regexp = regexp.MustCompile("^" + pattern)
			currentGroup.Rules = append(currentGroup.Rules, rule)

		case "crawl-delay":
			i, err := strconv.Atoi(val)
			if err == nil {
				robotsTxt.CrawlDelay = i
			}
		}
	}

	return robotsTxt
}

func (r *RobotsTxt) RulesForAgent(agent string) (rules []Rule, matched bool) {
	agent = strings.ToLower(strings.TrimSpace(agent))

	var exactRules []Rule
	var starRules []Rule

	for i := range r.Groups {
		g := &r.Groups[i]

		isExact := false
		isStar := false
		for _, a := range g.Agents {
			a = strings.ToLower(strings.TrimSpace(a))
			if a == agent {
				isExact = true
				break
			}
			if a == "*" {
				isStar = true
			}
		}

		if isExact {
			exactRules = append(exactRules, g.Rules...)
		} else if isStar {
			starRules = append(starRules, g.Rules...)
		}
	}

	// If agent name exactly matches listed user agent in robots.txt, use those.
	if len(exactRules) > 0 {
		return exactRules, true
	}
	// Otherwise default to the rules for all agents.
	if len(starRules) > 0 {
		return starRules, true
	}
	return nil, false
}

type RobotsManager struct {
	agent      string
	client     *http.Client
	domainUrl  string
	agentRules []Rule
	matchAll   bool
	crawlDelay int
}

func NewRobotsManager(agent string, domain string) *RobotsManager {
	domainUrl := "https://" + domain
	robots := fetchRobots(domainUrl)
	rules, matched := robots.RulesForAgent(agent)
	return &RobotsManager{
		agent:      agent,
		client:     &http.Client{Timeout: 10 * time.Second},
		domainUrl:  domainUrl,
		agentRules: rules,
		matchAll:   !matched,
		crawlDelay: robots.CrawlDelay,
	}
}

func (m *RobotsManager) Allowed(rawURL string) bool {
	u, err := url.Parse(rawURL)
	if err != nil {
		return false
	}
	if u.Scheme == "" || u.Host == "" {
		return false
	}

	if m.matchAll {
		return true
	}

	path := u.EscapedPath()
	if path == "" {
		path = "/"
	}
	if u.RawQuery != "" {
		path = path + "?" + u.RawQuery
	}
	return allowsWithRules(m.agentRules, path)
}

func fetchRobots(domainUrl string) *RobotsTxt {
	robotsURL, err := url.JoinPath(domainUrl, "/robots.txt")
	if err != nil {
		return &RobotsTxt{}
	}

	resp, err := http.Get(robotsURL)
	if err != nil {
		// If we can't fetch robots.txt, assume empty (allow everything).
		return &RobotsTxt{}
	}
	defer resp.Body.Close()

	// Once again, implied consent (not ok irl).
	if resp.StatusCode != http.StatusOK {
		return &RobotsTxt{}
	}

	return ParseRobotsTxt(resp.Body)
}

func allowsWithRules(rules []Rule, pathWithOptionalQuery string) bool {
	allowed := true
	bestLen := -1
	bestAllow := true

	for _, rule := range rules {
		// Empty Disallow means allow everything; empty Allow is a no-op.
		if rule.Path == "" {
			if !rule.Allow {
				continue
			}
		}
		if rule.Regexp != nil && rule.Regexp.MatchString(pathWithOptionalQuery) {
			l := len(rule.Path)
			if l > bestLen || (l == bestLen && rule.Allow && !bestAllow) {
				bestLen = l
				bestAllow = rule.Allow
				allowed = rule.Allow
			}
		}
	}

	return allowed
}
