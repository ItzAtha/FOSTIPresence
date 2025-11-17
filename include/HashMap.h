#ifndef HASHMAP_H
#define HASHMAP_H

#define ENABLE_COLLECTION_HELPERS

#include <ArduinoJson.h>

// Import type traits for checking if a type is an ArrayList or HashMap
#include <TypeTraits.h>

/**
 * @brief Represents a single entry in the hash map.
 * Each entry contains a key-value pair and a pointer to the next entry.
 *
 * @tparam K The type of the key.
 * @tparam V The type of the value.
 */
template <typename K, typename V> struct HashEntry {
  K key;
  V value;
  HashEntry *next;
};

/**
 * @brief A hash map class for storing key-value pairs.
 * This class provides a simple implementation of a hash map
 * that allows for efficient storage and retrieval of key-value pairs.
 *
 * @note This class is custom data collections class that inspired by Java's
 * HashMap.
 */
template <typename K, typename V> class HashMap {
  private:
  HashEntry<K, V> *head;
  HashEntry<K, V> *tail;
  size_t count = 0;

  public:
  using mapped_type = V;
  using is_hashmap = void;

  /**
   * @brief Default constructor for the HashMap.
   * Initializes an empty hash map with no entries.
   */
  HashMap() : head(nullptr), tail(nullptr) {}

  /**
   * @brief Copy constructor for the HashMap.
   * Creates a new hash map by copying entries from another hash map.
   *
   * @param other The hash map to copy from.
   */
  HashMap(const HashMap &other) : head(nullptr), tail(nullptr) {
    other.foreach (
        [this](const K &key, const V &value) { this->put(key, value); });
  }

  /**
   * @brief Assignment operator for the HashMap.
   * Assigns the contents of another hash map to this hash map.
   *
   * @param other The hash map to assign from.
   * @return A reference to this hash map.
   */
  HashMap &operator=(const HashMap &other) {
    if (this != &other) {
      clear();
      other.foreach (
          [this](const K &key, const V &value) { this->put(key, value); });
    }
    return *this;
  }

  /**
   * @brief Destructor for the HashMap.
   * Cleans up all entries in the hash map to prevent memory leaks.
   */
  ~HashMap() { clear(); }

  /**
   * @brief Inserts a key-value pair into the hash map.
   * If the key already exists, it will update the value.
   *
   * @param key The key to insert or update.
   * @param value The value associated with the key.
   */
  void put(const K &key, const V &value) {
    HashEntry<K, V> *newEntry = new HashEntry<K, V>{key, value, nullptr};
    if (!head) {
      head = tail = newEntry;
    } else {
      tail->next = newEntry;
      tail = newEntry;
    }
    count++;
  }

  /**
   * @brief Updates the value associated with the given key.
   * If the key does not exist, it will insert a new key-value pair.
   *
   * @param key The key to update or insert.
   * @param newValue The new value to associate with the key.
   */
  void update(const K &key, const V &newValue) {
    HashEntry<K, V> *current = head;
    while (current) {
      if (current->key == key) {
        current->value = newValue;
        return;
      }
      current = current->next;
    }
    // If key doesn't exist, insert it
    put(key, newValue);
  }

  /**
   * @brief Retrieves the value associated with the given key.
   * If the key does not exist, it returns a default-constructed value.
   *
   * @param key The key to search for.
   * @return The value associated with the key, or a default value if not found.
   */
  V get(const K &key) {
    HashEntry<K, V> *current = head;
    while (current) {
      if (current->key == key) {
        return current->value;
      }
      current = current->next;
    }
    return V();
  }

  /**
   * @brief Retrieves the value associated with the given key, or a default
   * value if the key does not exist.
   *
   * @param key The key to search for.
   * @param defaultValue The value to return if the key is not found.
   * @return The value associated with the key, or the default value if not
   * found.
   */
  V getOrDefault(const K &key, const V &defaultValue) {
    HashEntry<K, V> *current = head;
    while (current) {
      if (current->key == key) {
        return current->value;
      }
      current = current->next;
    }
    return defaultValue;
  }

  /**
   * @brief Checks if the hash map contains the specified key.
   * This method iterates through the entries in the hash map
   * to determine if the key exists.
   *
   * @param key The key to check for existence.
   * @return True if the key exists, false otherwise.
   */
  bool containsKey(const K &key) const {
    HashEntry<K, V> *current = head;
    while (current) {
      if (current->key == key) {
        return true;
      }
      current = current->next;
    }
    return false;
  }

  /**
   * @brief Checks if the hash map contains the specified value.
   * This method iterates through the entries in the hash map
   * to determine if the value exists.
   *
   * @param value The value to check for existence.
   * @return True if the value exists, false otherwise.
   */
  bool containsValue(const V &value) const {
    HashEntry<K, V> *current = head;
    while (current) {
      if (current->value == value) {
        return true;
      }
      current = current->next;
    }
    return false;
  }

  /**
   * @brief Removes the entry with the specified key from the hash map.
   * This method searches for the key and removes the corresponding entry
   * if it exists.
   *
   * @param key The key of the entry to remove.
   * @return True if the entry was removed, false if the key was not found.
   */
  bool remove(const K &key) {
    HashEntry<K, V> *current = head;
    HashEntry<K, V> *previous = nullptr;

    while (current) {
      if (current->key == key) {
        if (previous) {
          previous->next = current->next;
        } else {
          head = current->next;
        }
        count--;
        delete current;
        return true;
      }
      previous = current;
      current = current->next;
    }
    return false;
  }

  /**
   * @brief Checks if the hash map is empty.
   * This method returns true if there are no entries in the hash map,
   * and false otherwise.
   *
   * @return True if the hash map is empty, false otherwise.
   */
  bool isEmpty() const { return head == nullptr; }

  /**
   * @brief Clears all entries in the hash map.
   * This method removes all entries from the hash map,
   * effectively resetting it to an empty state.
   */
  void clear() {
    HashEntry<K, V> *current = head;
    while (current != nullptr) {
      HashEntry<K, V> *toDelete = current;
      current = current->next;
      delete toDelete;
    }
    head = tail = nullptr;
    count = 0;
  }

  /**
   * @brief Returns the number of entries in the hash map.
   * This method returns the count of key-value pairs stored in the hash map.
   *
   * @return The number of entries in the hash map.
   */
  size_t size() const { return count; }

  /**
   * @brief Iterates over each key-value pair in the hash map.
   * This method allows you to perform an operation on each entry
   * in the hash map using a callback function.
   *
   * @param callback The function to call for each key-value pair.
   */
  template <typename Callback> void foreach (Callback callback) const {
    HashEntry<K, V> *current = head;
    while (current) {
      callback(current->key, current->value);
      current = current->next;
    }
  }

#ifdef ENABLE_COLLECTION_HELPERS
  /**
   * @brief Converts the hash map to a JSON document.
   * This method creates a JSON representation of the hash map,
   * including all key-value pairs.
   *
   * @return A JsonDocument representing the hash map.
   */
  JsonDocument toJson() const {
    JsonDocument doc;

    HashEntry<K, V> *current = head;
    while (current) {
      K &key = current->key;
      V &value = current->value;

      if constexpr (is_arraylist<V>::value) {
        using ElementType = typename V::value_type;
        if constexpr (::is_hashmap<ElementType>::value ||
                      is_arraylist<ElementType>::value) {
          Serial.println("Nested ArrayList/HashMap not supported in toJson()");
          doc[key] = String("unsupported");
        } else {
          JsonArray data = doc.createNestedArray(key);
          for (size_t i = 0; i < value.size(); i++) {
            data.add(value.get(i));
          }
        }
      } else if constexpr (::is_hashmap<V>::value) {
        JsonObject data = doc.createNestedObject(key);

        value.foreach ([&data](const auto &key2, const auto &value2) {
          assignToJsonObject(data, key2, value2);
        });
      } else {
        doc[key] = value;
      }

      current = current->next;
    }

    return doc;
  }

  /**
   * @brief Converts the hash map to a string representation.
   * This method creates a string that represents the hash map
   * in a key-value format.
   *
   * @return A string representation of the hash map.
   */
  String toString() const {
    String result = "{";
    bool first = true;

    foreach ([&result, &first](const K &key, const V &value) {
      if (!first) {
        result += ", ";
      }
      first = false;
      result += "\"" + String(key) + "\": \"" + String(value) + "\"";
    })
      ;

    result += "}";
    return result;
  }
#endif
};

/**
 * @brief Assigns a value to a JSON object.
 * This function checks if the value is an ArrayList or HashMap,
 * and throws an exception if it is, as nested collections are not supported.
 *
 * @tparam KeyT The type of the key.
 * @tparam ValueT The type of the value.
 * @param obj The JSON object to assign the value to.
 * @param key The key for the value in the JSON object.
 * @param value The value to assign.
 *
 * @throws std::invalid_argument If the value is an ArrayList or HashMap.
 * @note This function is used to ensure that nested collections
 *       are not allowed in the JSON object.
 */
template <typename KeyT, typename ValueT>
void assignToJsonObject(JsonObject &obj, const KeyT &key, const ValueT &value) {
  if constexpr (is_arraylist<ValueT>::value || is_hashmap<ValueT>::value) {
    Serial.println("Nested ArrayList/HashMap not supported in toJson()");
    obj[key] = String("unsupported");
  } else {
    obj[key] = value;
  }
};

#endif