#if defined(USE_JEMALLOC)
#include <stdlib.h>
#include <jemalloc/jemalloc.h>
#include <malloc.h>

static void my_init_hook(void);
static void *my_malloc_hook(size_t, const void *);
static void *my_realloc_hook(void *, size_t, const void *);
static void my_free_hook(void *, const void *);

void (*__malloc_initialize_hook)(void) = my_init_hook;

static void
my_init_hook(void) {
	__malloc_hook = my_malloc_hook;
	__realloc_hook = my_realloc_hook;
	__free_hook = my_free_hook;
}

static void *
my_malloc_hook(size_t size, const void * caller) {
	return je_malloc(size);
}

static void *
my_realloc_hook(void * ptr, size_t size, const void * caller) {
	return je_realloc(ptr, size);
}

static void
my_free_hook(void * ptr, const void * caller) {
	je_free(ptr);
}
#endif
