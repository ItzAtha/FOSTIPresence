#ifndef TYPETRAITS_H
#define TYPETRAITS_H

#include <type_traits>

/**
 * @brief Type traits to check if a type is an ArrayList.
 * These traits are used to determine if a type is an ArrayList
 * and to provide compile-time checks for nested collections.
 *
 * @note This file is part of the custom data collections library.
 */
template <typename, typename = void> struct is_arraylist : std::false_type {};

/**
 * @brief Specialization for ArrayList types.
 * This specialization checks if a type has a member type `is_arraylist`
 * to determine if it is an ArrayList.
 *
 * @param T The type to check.
 * @return std::true_type if T is an ArrayList, otherwise std::false_type.
 */
template <typename T>
struct is_arraylist<T, std::void_t<typename T::is_arraylist>> : std::true_type {
};

/**
 * @brief Type traits to check if a type is a HashMap.
 * These traits are used to determine if a type is a HashMap
 * and to provide compile-time checks for nested collections.
 *
 * @note This file is part of the custom data collections library.
 */
template <typename, typename = void> struct is_hashmap : std::false_type {};

/**
 * @brief Specialization for HashMap types.
 * This specialization checks if a type has a member type `is_hashmap`
 * to determine if it is a HashMap.
 *
 * @param T The type to check.
 * @return std::true_type if T is a HashMap, otherwise std::false_type.
 */
template <typename T>
struct is_hashmap<T, std::void_t<typename T::is_hashmap>> : std::true_type {};

#endif