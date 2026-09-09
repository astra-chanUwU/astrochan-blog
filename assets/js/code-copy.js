document.addEventListener('click', async (event) => {
  const button = event.target.closest('[data-copy-code]');
  if (!button) return;

  const code = button.closest('.code-block')?.querySelector('code');
  if (!code) return;

  const copyText = async (text) => {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(text);
      return;
    }

    const field = document.createElement('textarea');
    field.value = text;
    field.setAttribute('readonly', '');
    field.style.position = 'fixed';
    field.style.opacity = '0';
    document.body.append(field);
    field.select();
    document.execCommand('copy');
    field.remove();
  };

  try {
    await copyText(code.textContent);
    button.classList.add('is-copied');
    button.setAttribute('aria-label', 'Copied');
    button.title = 'Copied';

    window.clearTimeout(button.copyResetTimer);
    button.copyResetTimer = window.setTimeout(() => {
      button.classList.remove('is-copied');
      button.setAttribute('aria-label', 'Copy code');
      button.title = 'Copy code';
    }, 1600);
  } catch {
    button.setAttribute('aria-label', 'Copy failed');
    button.title = 'Copy failed';
  }
});
