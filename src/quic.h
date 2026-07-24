#include "lsquic.h"
#include "lsquic_types.h"
#include "lsxpack_header.h"

void lsxpack_header_set_val_len(struct lsxpack_header *hdr, lsxpack_strlen_t len);
lsxpack_strlen_t lsxpack_header_get_val_len(struct lsxpack_header *hdr);
lsxpack_strlen_t lsxpack_header_get_name_len(struct lsxpack_header *hdr);
char *lsxpack_header_get_buf(struct lsxpack_header *hdr);
void *lsxpack_header_get_name_ptr(struct lsxpack_header *hdr);
void *lsxpack_header_get_val_ptr(struct lsxpack_header *hdr);
void lsxpack_header_set_buf(struct lsxpack_header *hdr, char *buf);
void lsxpack_header_zero_init(struct lsxpack_header *hdr);
size_t lsxpack_header_sizeof();
void
lsxpack_header_prepare_decode_(lsxpack_header_t *hdr,
                              char *out, size_t offset, size_t len);
void
lsxpack_header_set_offset2_(lsxpack_header_t *hdr, const char *buf,
                           size_t name_offset, size_t name_len,
                           size_t val_offset, size_t val_len);