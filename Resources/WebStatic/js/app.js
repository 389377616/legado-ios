let booksData = [];
let sourcesData = [];

async function loadBooks() {
    const list = document.getElementById('bookList');
    if (!list) return;

    try {
        document.getElementById('loading').style.display = 'block';
        const res = await fetch('/api/books');
        if (!res.ok) throw new Error('API fetch failed');
        
        booksData = await res.json();
        renderBooks(booksData);
    } catch (e) {
        list.innerHTML = `<div class="no-data">加载失败: ${e.message}</div>`;
    } finally {
        document.getElementById('loading').style.display = 'none';
    }
}

function renderBooks(data) {
    const list = document.getElementById('bookList');
    if (data.length === 0) {
        list.innerHTML = '<div class="no-data">暂无书籍</div>';
        return;
    }

    list.innerHTML = data.map(book => {
        const title = book.name || book.title || '未知书名';
        const author = book.author || '佚名';
        let progress = 0;
        let readChapter = '0';
        let totalChapter = '0';
        if (book.durChapterIndex !== undefined && book.totalChapterNum !== undefined && book.totalChapterNum > 0) {
            progress = (book.durChapterIndex / book.totalChapterNum) * 100;
            readChapter = book.durChapterIndex;
            totalChapter = book.totalChapterNum;
        } else if (book.progress) {
            progress = book.progress;
        }
        
        return `
            <div class="book-card">
                <div class="book-title">${escapeHTML(title)}</div>
                <div class="book-author">${escapeHTML(author)}</div>
                <div class="book-progress">
                    <div class="progress-bar" style="width: ${Math.min(100, progress)}%"></div>
                    <div class="progress-text">${Math.round(progress)}% (${readChapter}/${totalChapter})</div>
                </div>
            </div>
        `;
    }).join('');
}

function filterBooks() {
    const term = document.getElementById('searchInput').value.toLowerCase();
    const filtered = booksData.filter(b => 
        (b.name && b.name.toLowerCase().includes(term)) || 
        (b.title && b.title.toLowerCase().includes(term)) || 
        (b.author && b.author.toLowerCase().includes(term))
    );
    renderBooks(filtered);
}

function sortBooks() {
    const sortBy = document.getElementById('sortSelect').value;
    let sorted = [...booksData];
    
    sorted.sort((a, b) => {
        const titleA = (a.name || a.title || '').toLowerCase();
        const titleB = (b.name || b.title || '').toLowerCase();
        
        let progA = a.progress || 0;
        if (a.durChapterIndex !== undefined && a.totalChapterNum) progA = a.durChapterIndex / a.totalChapterNum;
        let progB = b.progress || 0;
        if (b.durChapterIndex !== undefined && b.totalChapterNum) progB = b.durChapterIndex / b.totalChapterNum;

        switch (sortBy) {
            case 'name_asc': return titleA.localeCompare(titleB);
            case 'name_desc': return titleB.localeCompare(titleA);
            case 'progress_desc': return progB - progA;
            case 'progress_asc': return progA - progB;
            default: return 0;
        }
    });
    renderBooks(sorted);
}

async function loadSources() {
    const list = document.getElementById('sourceList');
    if (!list) return;

    try {
        document.getElementById('loading').style.display = 'block';
        const res = await fetch('/api/sources');
        if (!res.ok) throw new Error('API fetch failed');
        
        sourcesData = await res.json();
        renderSources(sourcesData);
    } catch (e) {
        list.innerHTML = `<tr><td colspan="5" class="no-data">加载失败: ${e.message}</td></tr>`;
    } finally {
        document.getElementById('loading').style.display = 'none';
    }
}

function renderSources(data) {
    const list = document.getElementById('sourceList');
    if (data.length === 0) {
        list.innerHTML = '<tr><td colspan="5" class="no-data">暂无书源</td></tr>';
        return;
    }

    list.innerHTML = data.map((src, index) => {
        const name = src.bookSourceName || src.name || '未知书源';
        const url = src.bookSourceUrl || src.url || '-';
        const group = src.bookSourceGroup || src.group || '-';
        
        let enabled = src.enabled !== undefined ? src.enabled : true;
        if (typeof enabled === 'string') enabled = (enabled === 'true' || enabled === '1');
        else if (typeof enabled === 'number') enabled = enabled === 1;

        return `
            <tr>
                <td><strong>${escapeHTML(name)}</strong></td>
                <td><a href="${escapeHTML(url)}" target="_blank" style="color:var(--primary-color)">${escapeHTML(url)}</a></td>
                <td><span style="background:#eee;padding:2px 6px;border-radius:4px;font-size:0.8rem">${escapeHTML(group)}</span></td>
                <td>
                    <span style="color: ${enabled ? '#34c759' : '#ff3b30'}">
                        ${enabled ? '启用' : '禁用'}
                    </span>
                </td>
                <td>
                    <button class="btn-toggle ${enabled ? 'btn-disable' : 'btn-enable'}" 
                            onclick="toggleSource('${escapeHTML(url)}', ${!enabled})">
                        ${enabled ? '禁用' : '启用'}
                    </button>
                </td>
            </tr>
        `;
    }).join('');
}

function filterSources() {
    const term = document.getElementById('searchInput').value.toLowerCase();
    const filtered = sourcesData.filter(s => {
        const name = s.bookSourceName || s.name || '';
        const group = s.bookSourceGroup || s.group || '';
        return name.toLowerCase().includes(term) || group.toLowerCase().includes(term);
    });
    renderSources(filtered);
}

async function toggleSource(url, enable) {
    try {
        const sourceIndex = sourcesData.findIndex(s => (s.bookSourceUrl || s.url) === url);
        if (sourceIndex >= 0) {
            sourcesData[sourceIndex].enabled = enable;
            filterSources();
        }
        
       console.log('Toggled source:', url, enable);
       
    } catch (e) {
        alert('修改失败: ' + e.message);
        loadSources();
    }
}

function escapeHTML(str) {
    if (str === null || str === undefined) return '';
    const p = document.createElement('p');
    p.textContent = str;
    return p.innerHTML;
}