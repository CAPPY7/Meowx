#ifndef MEOWX_MPV_H
#define MEOWX_MPV_H

#include <stdint.h>
#include <mpv/client.h>
#include <mpv/render.h>

// Commands are joined with ASCII unit separator 0x1F, in order.
int meowx_command_sep(mpv_handle *ctx, const char *joined);

// Creates an OpenGL render context. The CGL context must already be current.
int meowx_gl_create_render(mpv_render_context **out_ctx, mpv_handle *mpv);

// Renders into the framebuffer currently bound on the current context.
int meowx_gl_render(mpv_render_context *ctx, int width, int height, int flip_y, int block);

// Renders into an explicit framebuffer object.
int meowx_gl_render_fbo(mpv_render_context *ctx, unsigned int fbo, int width, int height, int flip_y);

int meowx_gl_make_fbo(int width, int height, unsigned int *fbo, unsigned int *texture);
void meowx_gl_read_rgba_flipped(unsigned int fbo, int width, int height, unsigned char *dst);
void meowx_gl_delete_fbo(unsigned int fbo, unsigned int texture);

// Returned pointers are CGLPixelFormatObj / CGLContextObj. Caller releases them.
void *meowx_gl_pixel_format_for_display(uint32_t mask);
void *meowx_gl_offscreen_context(void);
void *meowx_cgl_get_current(void);
void meowx_cgl_set_current(void *ctx);
void meowx_cgl_clear_current(void);
void meowx_cgl_release_pixel_format(void *pixel_format);
void meowx_cgl_release_context(void *ctx);
void meowx_gl_lock(void);
void meowx_gl_unlock(void);

#endif
