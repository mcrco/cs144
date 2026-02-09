import tensorflow as tf
import pandas as pd
import numpy as np
import networkx as nx
import scipy
from scipy import stats
import json
import random
from tqdm import tqdm

DEFAULT_CONFIG = {
    "embed_size": 256,
    "num_layers": 5,
    "num_folds": 5,
    "num_epochs": 10,
}

def set_seed(seed):
    """Set random seed for reproducibility across all libraries."""
    random.seed(seed)
    np.random.seed(seed)
    tf.random.set_seed(seed)


def _normalize_array_by_rank(true_value, nr_nodes):
    rank = np.argsort(true_value, kind="mergesort", axis=None)
    norm = np.empty([nr_nodes])

    for i in range(0, nr_nodes):
        norm[rank[i]] = float(i + 1) / float(nr_nodes)

    max_val = np.amax(norm)
    min_val = np.amin(norm)
    if max_val > 0.0 and max_val > min_val:
        for i in range(0, nr_nodes):
            norm[i] = 2.0 * (float(norm[i] - min_val) / float(max_val - min_val)) - 1.0
    else:
        print("Max value = 0")

    return norm, rank

def load_dataset(path):
    G = nx.read_edgelist(
        path,
        comments="#",
        delimiter=None,
        create_using=nx.DiGraph,
        nodetype=None,
        data=True,
        edgetype=None,
        encoding="utf-8",
    )

    deg_lst = [val for (node, val) in G.degree()]
    nr_nodes = G.number_of_nodes()

    degree_norm, degree_rank = _normalize_array_by_rank(deg_lst, nr_nodes)
    b = [v for v in nx.betweenness_centrality(G).values()]
    BC_norm_cent, BC_cent_rank = _normalize_array_by_rank(b, nr_nodes)
    return G, nr_nodes, degree_norm, degree_rank, BC_norm_cent, BC_cent_rank


def Structure2Vec(G, nr_nodes, degree_norm, num_features=1, embed_size=512, layers=2):
    # build feature matrix
    def get_degree(i):
        return degree_norm[i]

    def build_feature_matrix():
        n = nr_nodes
        feature_matrix = []
        for i in range(0, n):
            feature_matrix.append(get_degree(i))
        return feature_matrix

    # Structure2Vec node embedding
    A = nx.to_numpy_array(G)
    dim = [nr_nodes, num_features]

    node_features = tf.cast(build_feature_matrix(), tf.float32)
    node_features = tf.reshape(node_features, dim)

    initializer = tf.compat.v1.keras.initializers.VarianceScaling(
        scale=1.0, mode="fan_avg", distribution="uniform"
    )

    A = tf.sparse.from_dense(A)
    A = tf.cast(A, tf.float32)
    w1 = tf.Variable(
        initializer((num_features, embed_size)),
        trainable=True,
        dtype=tf.float32,
        name="w1",
    )
    w2 = tf.Variable(
        initializer((embed_size, embed_size)),
        trainable=True,
        dtype=tf.float32,
        name="w2",
    )
    w3 = tf.Variable(
        initializer((1, embed_size)), trainable=True, dtype=tf.float32, name="w3"
    )
    w4 = tf.Variable(initializer([]), trainable=True, dtype=tf.float32, name="w4")

    wx_all = tf.matmul(node_features, w1)  # NxE

    # computing X1:
    weight_sum_init = tf.sparse.reduce_sum(A, axis=1, keepdims=True)
    n_nodes = tf.shape(input=A)[1]

    weight_sum = tf.multiply(weight_sum_init, w4)
    weight_sum = tf.nn.relu(weight_sum)  # Nx1
    weight_sum = tf.matmul(weight_sum, w3)  # NxE

    weight_wx = tf.add(wx_all, weight_sum)
    current_mu = tf.nn.relu(weight_wx)  # NxE = H^0

    for i in range(0, layers):
        neighbor_sum = tf.sparse.sparse_dense_matmul(A, current_mu)
        neighbor_linear = tf.matmul(neighbor_sum, w2)  # NxE
        current_mu = tf.nn.relu(tf.add(neighbor_linear, weight_wx))  # NxE

    mu_all = current_mu
    return mu_all


def build_model(embed_size, num_layers):
    model = tf.keras.Sequential()
    model.add(tf.keras.Input(shape=(embed_size,)))

    for _ in range(num_layers):
        model.add(tf.keras.layers.Dense(int(embed_size / 2), activation="relu"))

    model.add(tf.keras.layers.Dense(1))
    optimizer = tf.keras.optimizers.SGD(learning_rate=0.001, clipnorm=10.0)
    model.compile(optimizer=optimizer, loss="mse")
    model.summary()
    return model


def train_model(G, nr_nodes, degree_norm, embed_size, num_layers, num_folds, num_epochs, y_true, seed=42):
    # set seed for consistency across training runs
    set_seed(seed)

    mu_all = Structure2Vec(
        G, nr_nodes, degree_norm, embed_size=embed_size
    )
    x_train = mu_all

    all_scores = []
    k = num_folds
    num_val_samples = len(x_train) // k
    for i in range(k):
        model = build_model(embed_size, num_layers)
        val_data = x_train[i * num_val_samples : (i + 1) * num_val_samples]
        val_targets = y_true[i * num_val_samples : (i + 1) * num_val_samples]

        partial_train_data = np.concatenate(
            [
                x_train[: i * num_val_samples],
                x_train[(i + 1) * num_val_samples :],
            ],
            axis=0,
        )
        print(tf.shape(partial_train_data))

        partial_train_targets = np.concatenate(
            [
                y_true[: i * num_val_samples],
                y_true[(i + 1) * num_val_samples :],
            ],
            axis=0,
        )

        callbacks = tf.keras.callbacks.EarlyStopping(
            monitor="loss",
            min_delta=0,
            patience=3,
            verbose=0,
            mode="auto",
            baseline=None,
            restore_best_weights=False,
        )

        model.fit(
            partial_train_data,
            partial_train_targets,
            epochs=num_epochs,
            batch_size=1,
            callbacks=callbacks,
            verbose=0,
        )
        print("model.metrics_names: ", model.metrics_names)

        val_loss = model.evaluate(val_data, val_targets, verbose=0)
        all_scores.append(val_loss)
        del model

    callbacks = tf.keras.callbacks.EarlyStopping(
        monitor="loss",
        min_delta=0,
        patience=3,
        verbose=0,
        mode="auto",
        baseline=None,
        restore_best_weights=False,
    )
    model = build_model(embed_size, num_layers)
    model.fit(x_train, y_true, epochs=num_epochs, batch_size=1, callbacks=callbacks, verbose=0)
    x_new = x_train
    y_pred = model.predict(x_new)
    kendall_tau, p_value = scipy.stats.kendalltau(y_true, y_pred)
    return model, all_scores, kendall_tau, p_value

def eval_model(model, embed_size, num_layers, G, nr_nodes, degree_norm, y_true):
    mu_all = Structure2Vec(
        G, nr_nodes, degree_norm, embed_size=embed_size, layers=num_layers
    )
    x_test = mu_all
    y_pred = model.predict(x_test)

    if len(y_pred.shape) > 1:
        y_pred = y_pred.flatten()

    kendall_tau, p_value = scipy.stats.kendalltau(y_true, y_pred)
    return kendall_tau, p_value

def is_same_config(config1, config2):
    return (
        config1["embed_size"] == config2["embed_size"] and 
        config1["num_layers"] == config2["num_layers"] and 
        config1["num_folds"] == config2["num_folds"] and 
        config1["num_epochs"] == config2["num_epochs"]
    )

if __name__ == "__main__":

    embed_size_configs = [
        {**DEFAULT_CONFIG, "embed_size": es} for es in [16, 64, 256, 1024, 2048]
    ]

    num_layers_configs = [
        {**DEFAULT_CONFIG, "num_layers": nl} for nl in [1, 2, 4, 8, 16, 32]
    ]

    num_folds_configs = [
        {**DEFAULT_CONFIG, "num_folds": nf} for nf in [2, 5, 10]
    ]

    num_epochs_configs = [
        {**DEFAULT_CONFIG, "num_epochs": ne} for ne in [5, 10, 20]
    ]


    G08, nr_nodes08, degree_norm08, degree_rank08, BC_norm_cent08, BC_cent_rank08 = load_dataset("./data/p2p-Gnutella08.txt")
    G04, nr_nodes04, degree_norm04, degree_rank04, BC_norm_cent04, BC_cent_rank04 = load_dataset("./data/p2p-Gnutella04.txt")

    all_configs = embed_size_configs + num_layers_configs + num_folds_configs + num_epochs_configs
    all_stats = []
    for config in tqdm(all_configs):
        for existing_stats in all_stats:
            if is_same_config(config, existing_stats):
                continue
        embed_size, num_layers, num_folds, num_epochs = config["embed_size"], config["num_layers"], config["num_folds"], config["num_epochs"]
        model, all_scores, kendall_tau, p_value = train_model(
            G08, nr_nodes08, degree_norm08, embed_size, num_layers, num_folds, num_epochs, BC_norm_cent08
        )
        model.save(
            f"./models/GN08_model_{embed_size}embed_{num_layers}layers_"
            f"{num_folds}folds_{num_epochs}epochs.keras"
        )
        kendall_tau_test, p_value_test = eval_model(
            model, embed_size, num_layers, G04, nr_nodes04, degree_norm04, BC_norm_cent04
        )
        stats_dict = {
            **config,
            "train_val_losses": all_scores,
            "kendall_tau_train": kendall_tau,
            "p_value_train": p_value,
            "kendall_tau_test": kendall_tau_test,
            "p_value_test": p_value_test,
        }
        all_stats.append(stats_dict)
        print(stats_dict)

    with open("./stats.json", "w") as f:
        json.dump(all_stats, f, indent=4)