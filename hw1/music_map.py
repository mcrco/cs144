from tracemalloc import start
import bs4
import requests
from collections import deque



def get_path(start_url, end_url, num_threads=10):
    queue = deque([(start_url, [start_url])])
    visited = set([start_url])
    while queue:
        url, path = queue.popleft()
        print(url)
        if url == end_url:
            return path
        response = requests.get(url)
        soup = bs4.BeautifulSoup(response.text, "html.parser")
        link_div = soup.find("div", id="gnodMap")
        if link_div is None:
            continue
        links = link_div.find_all("a")
        for link in links:
            href = link.get("href")
            if href.startswith("https://www.music-map.com/"):
                continue
            next_url = "https://www.music-map.com/" + href
            if next_url in visited:
                continue
            visited.add(next_url)
            queue.append((next_url, path + [next_url]))
    return None

print(get_path("https://www.music-map.com/nikolai+rimsky-korsakov", "https://www.music-map.com/beyonce+knowles"))
print(get_path("https://www.music-map.com/lyle+mays", "https://www.music-map.com/taylor+swift"))