#let ans(body) = {
  block(
    width: 100%,
    stroke: 1pt + black,
    inset: 10pt,
    radius: 5pt,
    fill: luma(250),
    [
      *Solution*: #body
    ]
  )
}
#let prf(body) = { [_Proof:_ #body $square$] }
#let qs(body) = {
  set enum(numbering: "(a)")
  body
}
#let pt(body) = {
  body
}
#show link: set text(fill: blue)
#show link: underline

#align(center)[
  = CS 144 -- Homework 2
  Marco Yang
]

+ #qs[
  *Coauthorship Visualization*

  + #pt[
    Plot the histogram and ccdf of node degrees in coauthorship network. Calculate the average clustering coefficient, overall clustering coefficient, maximal diameter, and average diameter.

    #ans[
      Code is #link("https://github.com/mcrco/cs144/blob/main/hw2/p1.ipynb", [here]).

      #figure(
        image("img/1a-hist.png", width: 80%), 
        caption: "Histogram"
      )

      #figure(
        image("img/1a-ccdf.png", width: 80%), 
        caption: "CCDF"
      )

      - Average clustering coefficent: 0.5568782161697919
      - Overall clustering coefficient: 0.6288944756689877
      - Maximal diameter: 17
      - Average diameter: 6.049380016182999
    ]
  ]

  + #pt[
    Calculate the number of triangles. Assuming $T = EE[T]$, the expected number of triangles in an Erdos-Renyi graph with the same number of nodes, calculate the $p$ in $G(n, p)$ for that E-R graph.

    #ans[
      Code is #link("https://github.com/mcrco/cs144/blob/main/hw2/p1.ipynb", [here]).

      - Number of triangles: 47779
      - $p = 0.0159$
    ]
  ]

  + #pt[
    What distribution should the node degrees of a E-R graph take on? Is E-R a good model for coauthorship?

    #ans[
      An Erdos-Renyi graph should have a binomial distribution, but the coauthorship network clearly does not follow that. Erdos-Renyi is not a good model nodes since authors in similar fields are likely coauthors, so treating every edge as equally likely and random is wrong.
    ]
  ]
]

+ #qs[
  *Visualizing Networks*

  + #pt[
    #ans[
      Code is #link("https://github.com/mcrco/cs144/blob/main/hw2/p2.ipynb", [here]).

      #figure(
        image("img/2a.png"),
        caption: [Erdos-Renyi network with $n=40, p=0.23$.]
      )

      Analysis: yeah this graph looks ugly. Very random. I used the spring (nodes repel each other, edges are springs that pull together) layout since it shows just how boring this is. 
    ]
  ]

  + #pt[
    #ans[
      Code is #link("https://github.com/mcrco/cs144/blob/main/hw2/p2.ipynb", [here]).

      #figure(
        image("img/2b.png", width: 80%),
        caption: [SSBM with $n=30, k=3, A=0.7, B=0.1$.]
      )

      Analysis: much prettier this time. I had Claude implement a reverse spring layout (edges push apart, nodes attract) to show the clustering based on the community assignments. Each cluster/community is not very connected to itself but is very connected to the other clusters. I played around with parameters for the spring simulation until I got the clustering I wanted. I also highlighted nodes of the same community with a single color and made edges translucent so that overlapping edges could be distinguished from very sparse edges (e.g. heavy edge coloring in middle of the clusters, light edge coloring within each community) .
    ]
  ]

  + #pt[
    #ans[
      Code is #link("https://github.com/mcrco/cs144/blob/main/hw2/p2.ipynb", [here]).

      #figure(
        image("img/2c-100.png"),
        caption: [Web crawler network with $n=100$]
      )
      #figure(
        image("img/2c-300.png"),
        caption: [Web crawler network with $n=300$]
      )

      Analysis: $n=100$ has one super well connected component and lots of little satellites. Seems kinda similar to the Internet visualized (one SCC). $n=300$ gave more insight to how there were actually individual clusters within the big central cluster. Once again, a lot of satellites. Spring layout with translucent nodes + edges was perfect for this since highly connected clusters would get pulled together, while the less connected websites get pushed far away from the center, and areas of overlapping nodes and edges were well-visualized by the color intensity.
    ]
  ]
]

+ #qs[
  *The Navigation Paradox*

  Analyze the average shortest path using a greedy algorithm for a Watts-Strogatz graph with $n=1000, k=10, p=0.1$.

  #ans[
    Code is #link("https://github.com/mcrco/cs144/blob/main/hw2/p3.ipynb", [here]).

    - Average shortest path length: 4.5
    - Average greedy path length: 11.69

    The greedy algorithm isn't able to look ahead and take small steps towards a node that provides a much more optimal shortcut to the destination.
  ]
]

+ #qs[
  *Getting to Know Erdos Renyi*

  + #pt[
    #set enum(numbering: "(i)")
    *Clustering*

    + #pt[
      Calculate the expected number of triangles $EE[T]$, that $G(n,p)$ contains.

      #ans[
        The number of triplets is $binom(n, 3)$. The probability that any triple is connected in a triangle is $p^3$ since the probability of any edge existing is $p$. Thus,
        $
          EE[T] = binom(n, 3) p^3 = (n(n - 1)(n - 2))/6 p^3.
        $
      ]
    ]

    + #pt[
      Prove that $E[T]$ has a threshold. Specifically, find a function $pi(n)$ s.t. $lim_(n->infinity) EE[T] = infinity$ if $p in omega(pi(n))$ and $lim_(n -> infinity) EE[T] = 0$ if $p in o(pi(n))$.

      #ans[
        For large $n$, the above expected value is roughly
        $
          EE[T] approx (n^3p^3)/6.
        $ 

        Let $pi(n) = 1/n$. Since $n$ and $pi$ multiply out to a constant, if $p in omega(pi(n))$, $EE[T]$ explodes, while for $p in o(pi(n))$, $EE[T]$ disappears.
      ]
    ]

    Let $X$ be the event that a triangle is contained in $G$. Note that the previous part is insufficient to show that $pi(n)$ is a threshold for $X$. But we can show this fact with second moment method -- the same way we proved the result for isolated vertices in class. Since the general case is a bit nasty, we will focus on a specific setting here: $p(n) = pi(n) log(n)$. 

    #set enum(start: 3)
    + #pt[
      Show that $"Var"(T) in Theta(log^3(n))$. Hint: Think about how to express $T$ as a sum of binary r.v.s. Then, use casework to understand the covariance terms that result.

      #ans[
        For each triplet $i$, let $X_(i)$ be the random variable that is 1 if the triplet forms a triangle and 0 otherwise. We can express $T$ as a sum of all $X_(i)$. Then, we know that the variance is
        $
          "Var"(T) = sum_(i) "Var"(X_(i)) - 2 sum_(i < j) "Cov"(X_(i), X_(j)).
        $ 

        The variance of $T$ is the variance of a Bernoulli variable with probability $p^3$, which is $p^3(1-p^3)$. The number of triplets scales with $n^3$.

        The covariance is defined as
        $ "Cov"(X_(i), X_(j) = E[X_(i)X_(j)] - E[X_(i)]E[X_(j)]. $ 

        Notice that if the triplets $i$ and $j$ do not share a side, they are independent, and thus the covariance for them is 0. So for our calculations, we only consider triplets that share a side. The number of pairs of triplets that share a side is the number of combinations two pairs of points, which is
        $
          n_("adjacent triangles") = binom(n, 2) dot binom(n - 2, 2).
        $ 

        The probability of both triangles $i$ and $j$ being formed is the probability that all 5 lines that form the two triangles are present, which is $p^(5)$. Thus,
        $ 
          "Cov"(X_(i), X_(j)) &= E[X_(i)X_(j)] - E[X_(i)]E[X_(j)] \
          &= p^(5) - p^3p^3 \
          &= p^(5) - p^(6) \
        $ 

        Now, evaluating the variance altogether (and making some approximations since we are using $Theta$ notation),
        $
          "Var"(T) &= n^3 p^3(1-p^3) - 2 binom(n, 2) binom(n - 2, 2) (p^(5) - p^(6)) \
          &approx n^3 p^3 - n^3 p^(6) - n^(4) (p^(5 - p^(6))) \
          &approx n^3 p^(3) - n^(4) p^(5) underbrace(- n^3 p^(6) + n^(4) p^(6), "trivial in magnitude") \
          &approx n^3 p^3 - n^(4) p^(5).
        $ 

        Plugging in $p(n) = 1/n log(n)$, we have
        $
          "Var"(T) &= n^3 (log^3(n))/(n^3) - n^(4) (log^(5)(n))/(n^(5)) \
          &= log^3(n) underbrace(- (log^(5)(n))/n, "trivial") \
          &approx log^3(n) \
          &in Theta(log^3(n)).
        $ 
      ]
    ]

    + #pt[
      Use Chebyshev's Inequality to show that $Pr(T = 0) in o(1)$. Conclude that $lim_(n -> infinity) Pr(X) = 1$ for this particular $p$.

      #ans[
        Since 0 is $n^3p^3 / 6$ away from from the mean, the number of standard deviations it is away from the mean is
        $
          k in Theta((n^3)/6 dot (log^3(n))/(n^3) dot 1/(sqrt(log^3(n)))) = Theta(sqrt(log^3(n))).
        $ 

        Thus,
        $
          Pr(T = 0) = 1/(Theta(sqrt(log^3(n)))) in o(1).
        $ 

        Since the probability of no triangles grows infinitely small as $n$ increases, $lim_(n -> infinity) Pr(X) = 1$.
      ]
    ]
  ]

  + #pt[
    *Diameter*

    Suppose $p in (0, 1)$ is held constant. Prove that the maximal diameter of $G(n, p)$ equals 2 with a probability that approaches 1 as $n$ becomes large:
    $
      lim_(n -> infinity) P("diameter"(G(n,p)) = 2) = 1.
    $

    #ans[
      Notice that the maximal diameter being more than 2 is the same as there being two nodes that aren't in a triangle. For a pair of nodes to node be in a triangle, we need that there is no edge between them and no edge between them and a common node. This probability that two nodes $i$ and $j$ aren't in a triangle $p_"no triangle"(i, j)$ is
      $
        p_("no triangle")(i, j) = underbrace(1 - p, "no direct edge") + underbrace(1 - (1 - p^2)^(n - 2), "no common neighbor").
      $ 
      The $(1-p^2)^(n-2)$ term comes from the fact that for a third node $k$, the probability that it doesn't have an edge with both $i$ and $j$ is $1 - p^2$. The probability that every single 
    ]
  ]
]

+ #qs[
  *It's a small world after all*

  Consider the model in @p5graph. There are $n$ nodes in a directed ring, labelled $A_1, dots, A_(n)$. Every node is connected to the next with a directed link of length 1. Central node $B$ is connected to each of the nodes via a undirected link of length $1/2$ with probability $p$.

  #figure(
    image("img/sw_fig-1.png"),
    caption: [Graph model],
  ) <p5graph>

  + #pt[
    Consider nodes $A_(i)$ and $A_(j)$, $A_(j)$ being $k$ hops away from $A_(i)$ along the ring. Compute the probability $P(l, k)$ that the shortest path from $A_(i)$ to $A_(j)$ has length $l$. What is the expected value of the shortest path length from $A_(i)$ to $A_(j)$?

    Hint: Think about the two cases when $l < k$ and $l = k$ (there are sub-cases in the latter).

    #ans[
      #set enum(numbering: "1. ")
      If $l = k$, one of the following has happened:

      + none of the nodes along the path are connected to $B$.
        - probability of $(1 - p)^(k + 1)$.
        - $k + 1$ is the number of nodes in the path
      + exactly one of the nodes along the path is connected to $B$.
        - probability of $(k + 1) p (1-p)^(k)$.
        - $k + 1$ is the number of choices of the solo node to connect to $B$.
        - $p$ is the probability that the chosen solo node solo node is connected to $B$.
        - $(1 - p)^(k)$ is the probability that no other nodes are connected
      + there is a pair of consecutive nodes $A_(k), A_(k + 1)$ that are both connected to $B$, and none of the other nodes are connected.
        - probability of $k p^2(1-p)^(k - 1)$.
        - $k$ is the number of choices of the pair of adjacent nodes to connect to $B$.
        - $p^2$ is the probability that the chosen adjacent pair is connected to $B$.
        - $(1 - p)^(k-1)$ is the probability that no other nodes are connected

      Thus, 
      $
        p(k, k) &= (1-p)^(k - 1)((1-p)^2 + p(1-p)(k + 1) + p^2 k) \
        &= (1-p)^(k-1)(1 - p + p k).
      $ 

      If $l < k$, then there exists a shortcut path through $B$ between two nodes that are $k - l + 1$ apart (and no better shortcut path than this). The probability of this happening is 
      $
        p(l < k, k) = l p^2 (1 - p)^(l - 1)
      $ 

      - $l$ is number of choices of pairs that are $k - l + 1$ apart 
      - $p^2$ is the probability that the chosen pair is connected to $B$ 
      - $(1 - p)^(l - 1)$ is the probability there is no better shortcut
        - $l - 1$ is the number of nodes before or after the shortcut's endpoints.

      Thus, the expected value of the shortest path is
      $
        E[L(k)] &= (1-p)^(k - 1)(1 - p + p k) dot k + sum_(l=1)^(k - 1) l p^2 (1 - p)^(l - 1) dot l \
        &= k(1-p)^(k - 1)(1 - p + p k) + sum_(l=1)^(k - 1) l^2 p^2 (1 - p)^(l - 1).
      $ 
    ]
  ]

  + #pt[
    Compute the expected average shortest path between the nodes on the ring of the graph. How does this quantity scale with $n$? Contrast this with when the graph has no central node.

    #ans[
      Since there is circular symmetry for each of the nodes, the average shortest path between the nodes is just the average shortest path between a fixed node $A_(i)$ and any of the other nodes $A_(j), i != j$ (or alternatively, iterate over all possibilities for the number of hops between $A_(i), A_(j)$) which is
      $
        1/(n-1) sum_(k=1)^(n - 1) E[L(k)].
      $

      Looking at the expression for $E[L(k)]$ from the previous problem, we can notice that the first term corresponding to the event that $l = k$ is insignificant since the probability decreases exponentially with $k$.
    ]
  ]
]

