#ifndef ARRAYLIST_H
#define ARRAYLIST_H

// #define ENABLE_COLLECTION_HELPERS

/**
 * @brief A dynamic array class for storing items.
 * This class provides a simple implementation of a dynamic array
 * that can grow in size as needed.
 *
 * @note This class is custom data collections class that inspired by Java's
 * ArrayList.
 */
template <typename T> class ArrayList {
  private:
  T *items;
  size_t capacity;
  size_t count;

  /**
   * @brief Resizes the internal array to accommodate more items.
   * This method doubles the capacity of the internal array
   * and copies existing items to the new array.
   */
  void resize() {
    capacity *= 2;
    T *newItems = new T[capacity];
    for (size_t i = 0; i < count; i++) {
      newItems[i] = items[i];
    }
    delete[] items;
    items = newItems;
  }

  public:
  using value_type = T;
  using is_arraylist = void;

  /**
   * @brief Default constructor for the ArrayList.
   * Initializes an empty array list with a default initial capacity.
   *
   * @param initialCapacity The initial capacity of the array list.
   */
  ArrayList(size_t initialCapacity = 4) : capacity(initialCapacity), count(0) {
    items = new T[capacity];
  }

  /**
   * @brief Copy constructor for the ArrayList.
   * Creates a new array list by copying items from another array list.
   *
   * @param other The array list to copy from.
   */
  ArrayList(const ArrayList<T> &other)
      : capacity(other.capacity), count(other.count) {
    items = new T[capacity];
    for (size_t i = 0; i < count; i++) {
      items[i] = other.items[i];
    }
  }

  /**
   * @brief Assignment operator for the ArrayList.
   * Assigns the contents of another array list to this array list.
   *
   * @param other The array list to assign from.
   * @return A reference to this array list.
   */
  ArrayList &operator=(const ArrayList<T> &other) {
    if (this != &other) {
      delete[] items;
      capacity = other.capacity;
      count = other.count;
      items = new T[capacity];
      for (size_t i = 0; i < count; i++) {
        items[i] = other.items[i];
      }
    }
    return *this;
  }

  /**
   * @brief Destructor for the ArrayList.
   * Cleans up the internal array to prevent memory leaks.
   */
  ~ArrayList() { delete[] items; }

  /**
   * @brief Adds an item to the end of the list.
   * This method appends the specified item to the end of the list,
   * increasing the size of the list if necessary.
   *
   * @param item The item to add to the list.
   */
  void add(T item) {
    if (count == capacity) {
      resize();
    }
    items[count++] = item;
  }

  /**
   * @brief Gets the item at the specified index.
   * This method returns the item at the specified index in the list.
   *
   * @param index The index of the item to retrieve.
   * @throws std::out_of_range If the index is out of range.
   * @return The item at the specified index.
   */
  T get(size_t index) const {
    if (index < count) {
      return items[index];
    }
    throw std::out_of_range("Index out of range");
  }

  /**
   * @brief Removes the item at the specified index.
   * This method removes the item at the specified index from the list,
   * shifting subsequent items down to fill the gap.
   *
   * @param index The index of the item to remove.
   * @throws std::out_of_range If the index is out of range.
   */
  void remove(size_t index) {
    if (index < count) {
      for (size_t i = index; i < count - 1; i++) {
        items[i] = items[i + 1];
      }
      count--;
    } else {
      throw std::out_of_range("Index out of range");
    }
  }

  /**
   * @brief Removes the first occurrence of the specified item.
   * This method searches for the specified item in the list and removes
   * the first occurrence found, shifting subsequent items down to fill the gap.
   *
   * @param item The item to remove from the list.
   */
  void remove(const T &item) {
    size_t index = 0;
    for (size_t i = 0; i < count; i++) {
      if (items[i] == item) {
        index = i;
        break;
      }
    }
    remove(index);
  }

  /**
   * @brief Checks if the list is empty.
   * This method returns true if the list is empty, and false otherwise.
   *
   * @return True if the list is empty, false otherwise.
   */
  bool isEmpty() const { return count == 0; }

  /**
   * @brief Checks if the list contains the specified item.
   * This method checks if the specified item is present in the list.
   *
   * @param item The item to check for in the list.
   * @return True if the item is found, false otherwise.
   */
  bool contains(const T &item) const {
    size_t index = 0;
    for (size_t i = 0; i < count; i++) {
      if (items[i] == item) {
        index = i;
        return true;
      }
    }
    return false;
  }

  /**
   * @brief Clears all items from the list.
   * This method removes all items from the list and resets its size.
   */
  void clear() {
    delete[] items;
    items = new T[capacity];
    count = 0;
  }

  /**
   * @brief Gets the number of items in the list.
   * This method returns the number of items currently stored in the list.
   *
   * @return The number of items in the list.
   */
  size_t size() const { return count; }

#ifdef ENABLE_COLLECTION_HELPERS
  /**
   * @brief Converts the list to a string representation.
   * This method creates a string that represents the items in the list
   * in a comma-separated format.
   *
   * @return A string representation of the list.
   */
  String toString() const {
    String result = "[";
    for (size_t i = 0; i < count; i++) {
      result += items[i].toString();
      if (i < count - 1) {
        result += ", ";
      }
    }
    result += "]";
    return result;
  }
#endif
};

#endif
