#include "quic.h"

void lsxpack_header_set_val_len(struct lsxpack_header *hdr, lsxpack_strlen_t len) {
  hdr->val_len = len;
}

lsxpack_strlen_t lsxpack_header_get_val_len(struct lsxpack_header *hdr) {
  return hdr->val_len;
}

lsxpack_strlen_t lsxpack_header_get_name_len(struct lsxpack_header *hdr) {
  return hdr->val_len;
}

void *lsxpack_header_get_name_ptr(struct lsxpack_header *hdr) {
  return &hdr->buf[hdr->name_offset];
}
void *lsxpack_header_get_val_ptr(struct lsxpack_header *hdr) {
  return &hdr->buf[hdr->val_offset];
}

char *lsxpack_header_get_buf(struct lsxpack_header *hdr) {
  return hdr->buf;
}

void lsxpack_header_set_buf(struct lsxpack_header *hdr, char *buf) {
  hdr->buf = buf;
}

void lsxpack_header_zero_init(struct lsxpack_header *hdr) {
  memset(hdr, 0, sizeof(struct lsxpack_header));
}

size_t lsxpack_header_sizeof() {
  return sizeof(struct lsxpack_header);
}

void
lsxpack_header_prepare_decode_(lsxpack_header_t *hdr,
                              char *out, size_t offset, size_t len)
{
    memset(hdr, 0, sizeof(*hdr));
    hdr->buf = out;
    assert(offset <= LSXPACK_MAX_STRLEN);
    hdr->name_offset = (lsxpack_offset_t)offset;
    if (len > LSXPACK_MAX_STRLEN)
        hdr->val_len = LSXPACK_MAX_STRLEN;
    else
        hdr->val_len = (lsxpack_strlen_t)len;
}

void
lsxpack_header_set_offset2_(lsxpack_header_t *hdr, const char *buf,
                           size_t name_offset, size_t name_len,
                           size_t val_offset, size_t val_len)
{
    memset(hdr, 0, sizeof(*hdr));
    hdr->buf = (char *)buf;
    hdr->name_offset = (lsxpack_offset_t)name_offset;
    assert(name_len <= LSXPACK_MAX_STRLEN);
    hdr->name_len = (lsxpack_strlen_t)name_len;
    assert(val_offset <= LSXPACK_MAX_STRLEN);
    hdr->val_offset = (lsxpack_offset_t)val_offset;
    assert(val_len <= LSXPACK_MAX_STRLEN);
    hdr->val_len = (lsxpack_strlen_t)val_len;
}

